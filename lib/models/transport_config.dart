import 'package:equatable/equatable.dart';

enum TransportType {
  ble,
  wifiDirect,
  lan,
}

class TransportConfig extends Equatable {
  final TransportType type;
  final String serviceId;
  final int maxPeers;

  const TransportConfig({
    this.type = TransportType.wifiDirect, // Defaulting to Wi-Fi Direct/P2P via nearby_connections
    this.serviceId = 'com.example.offline_photo_share',
    this.maxPeers = 7,
  });

  @override
  List<Object?> get props => [type, serviceId, maxPeers];
}
