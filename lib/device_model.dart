class DeviceModel {
  final String ip;
  String name;
  String type; // es. Router, PC, Smartphone, Laptop
  List<int> openPorts;
  bool isScanningPorts;

  DeviceModel({
    required this.ip,
    this.name = 'Rilevamento in corso...',
    this.type = 'Sconosciuto',
    List<int>? openPorts,
    this.isScanningPorts = false,
  }) : openPorts = openPorts ?? [];
}
