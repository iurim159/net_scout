import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'network_service.dart';
import 'device_model.dart';

void main() => runApp(const NetScoutApp());

class NetScoutApp extends StatelessWidget {
  const NetScoutApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.cyan,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
      ),
      home: const ScanScreen(),
    );
  }
}

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _networkService = NetworkService();
  final List<DeviceModel> _devices = [];
  bool _isScanning = false;
  String _currentStatus = "Pronto per la scansione";

  void _startScan() async {
    setState(() {
      _devices.clear();
      _isScanning = true;
      _currentStatus = "Identificazione sottorete Wi-Fi...";
    });

    final subnet = await _networkService.getSubnet();
    if (subnet == null) {
      setState(() {
        _isScanning = false;
        _currentStatus = "Errore: Assicurati di essere connesso al Wi-Fi";
      });
      return;
    }

    setState(() => _currentStatus = "Scansione dispositivi su $subnet.0/24...");
    try {
      // Usiamo .listen() sullo stream invece di await
      _networkService.scanLanStream(subnet).listen(
        (device) {
          setState(() {
            _devices.add(device); // Aggiunge il dispositivo appena viene scoperto!
          });
          _scanDevicePorts(device); // Avvia subito il controllo porte per questo IP
        },
        onError: (error) {
          setState(() => _currentStatus = "Errore durante il rilevamento");
        },
        onDone: () {
          setState(() {
            _isScanning = false;
            _currentStatus = "Scansione completata. Analizzati ${_devices.length} host.";
          });
        },
      );
    } catch (e) {
      setState(() {
        _isScanning = false;
        _currentStatus = "Errore durante l'avvio della scansione";
      });
    }
  }

  void _scanDevicePorts(DeviceModel device) async {
    setState(() => device.isScanningPorts = true);
    final openPorts = await _networkService.scanPorts(device.ip);
    setState(() {
      device.openPorts = openPorts;
      device.isScanningPorts = false;
    });
  }

  IconData _getDeviceIcon(String type) {
    switch (type) {
      case 'Router': return LucideIcons.router;
      case 'Smartphone': return LucideIcons.smartphone;
      case 'PC': return LucideIcons.monitor;
      case 'Laptop': return LucideIcons.laptop;
      default: return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NetScout LAN', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E293B),
        centerTitle: true,
        elevation: 4,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Pannello di Controllo Superiore
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.cyan.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_isScanning ? 'Scansione Attiva' : 'Stato Radar', 
                          style: TextStyle(color: Colors.cyan.shade300, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(_currentStatus, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ),
                  _isScanning 
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.cyan))
                    : ElevatedButton.icon(
                        onPressed: _startScan,
                        icon: const Icon(LucideIcons.radar),
                        label: const Text('Scansiona'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.cyan.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Lista Risultati
            Expanded(
              child: _devices.isEmpty 
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.network, size: 64, color: Colors.blueGrey.shade600),
                        const SizedBox(height: 12),
                        const Text('Nessun dispositivo rilevato. Premi Scansiona.', style: TextStyle(color: Colors.white38)),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _devices.length,
                    itemBuilder: (context, index) {
                      final dev = _devices[index];
                      return Card(
                        color: const Color(0xFF1E293B),
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(14),
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF0F172A),
                            radius: 24,
                            child: Icon(_getDeviceIcon(dev.type), color: Colors.cyan.shade400),
                          ),
                          title: Text(dev.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('IP: ${dev.ip}', style: TextStyle(color: Colors.grey.shade400, fontFamily: 'monospace')),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Text('Porte Aperte: ', style: TextStyle(fontSize: 12, color: Colors.white54)),
                                  if (dev.isScanningPorts)
                                    const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.orange))
                                  else if (dev.openPorts.isEmpty)
                                    const Text('Nessuna rilevata (o chiusa)', style: TextStyle(fontSize: 12, color: Colors.red))
                                  else
                                    Wrap(
                                      spacing: 4,
                                      children: dev.openPorts.map((p) => Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: Colors.green.withOpacity(0.5)),
                                        ),
                                        child: Text('$p', style: const TextStyle(fontSize: 10, color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                                      )).toList(),
                                    )
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
