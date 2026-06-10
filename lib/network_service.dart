import 'dart:io';
import 'dart:isolate';

import 'device_model.dart';

class NetworkService {
  final List<int> _commonPorts = [
    20, // FTP Data
    21, // FTP Control
    22, // SSH
    23, // Telnet
    25, // SMTP
    53, // DNS
    67, // DHCP Server
    68, // DHCP Client
    80, // HTTP
    110, // POP3
    143, // IMAP
    443, // HTTPS
  ];

  Future<String?> getSubnet() async {
    try {
      final interfaces = await NetworkInterface.list();
      final candidates = <_NetworkCandidate>[];

      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (addr.type != InternetAddressType.IPv4 || addr.isLoopback) {
            continue;
          }

          final score = _scoreLocalInterface(interface.name, addr.address);
          if (score == null) continue;

          final blocks = addr.address.split('.');
          candidates.add(
            _NetworkCandidate(
              subnet: '${blocks[0]}.${blocks[1]}.${blocks[2]}',
              score: score,
            ),
          );
        }
      }

      if (candidates.isEmpty) return null;

      candidates.sort((a, b) => b.score.compareTo(a.score));
      return candidates.first.subnet;
    } catch (_) {
      return null;
    }
  }

  static int? _scoreLocalInterface(String interfaceName, String ip) {
    final name = interfaceName.toLowerCase();
    final blocks = ip.split('.');
    if (blocks.length != 4) return null;

    final first = int.tryParse(blocks[0]);
    final second = int.tryParse(blocks[1]);
    if (first == null || second == null) return null;

    if (first == 0 || first == 127 || (first == 169 && second == 254)) {
      return null;
    }

    const ignoredNames = [
      'rmnet',
      'ccmni',
      'wwan',
      'pdp',
      'cell',
      'mobile',
      'tun',
      'tap',
      'vpn',
      'ipsec',
      'clat',
      'dummy',
      'p2p',
      'lo',
      'docker',
      'vbox',
      'vmnet',
      'rndis',      // Hotspot USB Android
      'usb',        // Interfacce USB
      'tether',     // Tethering
      'bridge',     // Bridge di rete
      'nflog',      // Sistema
      'nfqueue',    // Sistema
      'vxlan',      // Virtualizzazione
      'br-',        // Bridge Docker
      'veth',       // Virtual Ethernet
    ];
    if (ignoredNames.any(name.contains)) return null;

    // Escludi IP strani come 10.114.x.x e 192.168.56.x (virtualizzazione)
    if ((first == 10 && second == 114) || (first == 192 && second == 168 && blocks[2] == '56')) {
      return null;
    }

    var score = 0;
    
    // MASSIMA PRIORITÀ per Wi-Fi - questo è quello che vogliamo!
    if (name.contains('wifi') || name.contains('wlan') || name.startsWith('wl') || name.contains('wi-fi')) {
      score += 10000;
      return score;
    }

    // Se arriva qua, non è Wi-Fi - dai score bassissimo (solo per fallback)
    if (name.contains('eth') || name.startsWith('en')) {
      score += 10;  // Molto basso
    }

    // Priorità subnet per fallback
    if (first == 192 && second == 168) {
      score += 5;
    } else if (first == 172 && second >= 16 && second <= 31) {
      score += 4;
    } else if (first == 10) {
      score += 3;
    }

    return score > 0 ? score : null;
  }

  Stream<DeviceModel> scanLanStream(String subnet) {
    final receivePort = ReceivePort();

    Isolate.spawn(_ultraFastScanBackground, {
      'subnet': subnet,
      'sendPort': receivePort.sendPort,
    });

    return receivePort
        .map((message) {
          if (message == null) {
            receivePort.close();
            return null;
          }

          final data = message as Map<String, dynamic>;
          return DeviceModel(
            ip: data['ip'],
            name: data['name'],
            type: data['type'],
          );
        })
        .where((device) => device != null)
        .cast<DeviceModel>();
  }

  static void _ultraFastScanBackground(Map<String, dynamic> args) async {
    final subnet = args['subnet'] as String;
    final sendPort = args['sendPort'] as SendPort;

    final ipList = List.generate(254, (i) => '$subnet.${i + 1}');
    final scanningTasks = ipList.map((ip) async {
      final deviceMap = await _checkSingleIp(ip);
      if (deviceMap != null) {
        sendPort.send(deviceMap);
      }
    }).toList();

    await Future.wait(scanningTasks);
    sendPort.send(null);
  }

  static Future<Map<String, dynamic>?> _checkSingleIp(String ip) async {
    final portsToCheck = [80, 443, 22, 23, 135, 445];
    for (final port in portsToCheck) {
      try {
        final socket = await Socket.connect(
          ip,
          port,
          timeout: const Duration(milliseconds: 150),
        );
        await socket.close();
        return await _buildDeviceMap(ip);
      } catch (_) {}
    }

    final systemPorts = [135, 445];
    for (final port in systemPorts) {
      try {
        final socket = await Socket.connect(
          ip,
          port,
          timeout: const Duration(milliseconds: 120),
        );
        await socket.close();
        return await _buildDeviceMap(ip);
      } catch (e) {
        final errorStr = e.toString().toLowerCase();
        if (errorStr.contains('refused') ||
            errorStr.contains('rifiutata') ||
            errorStr.contains('reset')) {
          return await _buildDeviceMap(ip);
        }
      }
    }

    try {
      final lookup = await InternetAddress(
        ip,
      ).reverse().timeout(const Duration(milliseconds: 100));
      if (lookup.host != ip &&
          lookup.host.isNotEmpty &&
          !lookup.host.contains('unknown')) {
        return await _buildDeviceMap(ip);
      }
    } catch (_) {}

    return null;
  }

  static Future<Map<String, dynamic>> _buildDeviceMap(String ip) async {
    String name = 'Dispositivo LAN attivo';
    String type = 'Sconosciuto';

    try {
      final lookup = await InternetAddress(ip).reverse();
      name = lookup.host;
      final hostLower = lookup.host.toLowerCase();

      if (hostLower.contains('desktop') ||
          hostLower.contains('pc') ||
          hostLower.contains('win')) {
        type = 'PC';
      } else if (hostLower.contains('phone') ||
          hostLower.contains('android') ||
          hostLower.contains('ios')) {
        type = 'Smartphone';
      } else if (hostLower.contains('gateway') ||
          hostLower.contains('router') ||
          hostLower.contains('modem')) {
        type = 'Router';
      } else if (hostLower.contains('macbook') || hostLower.contains('laptop')) {
        type = 'Laptop';
      }
    } catch (_) {}

    return {'ip': ip, 'name': name, 'type': type};
  }

  Future<List<int>> scanPorts(String ip) async {
    final openPorts = <int>[];
    for (final port in _commonPorts) {
      try {
        final socket = await Socket.connect(
          ip,
          port,
          timeout: const Duration(milliseconds: 100),
        );
        openPorts.add(port);
        await socket.close();
      } catch (_) {}
    }
    return openPorts;
  }
}

class _NetworkCandidate {
  const _NetworkCandidate({required this.subnet, required this.score});

  final String subnet;
  final int score;
}
