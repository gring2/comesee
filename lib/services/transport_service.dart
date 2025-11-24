import 'dart:async';
import 'dart:typed_data';

enum ConnectionStatus {
  connected,
  disconnected,
  connecting,
  error,
}

abstract class TransportService {
  // Initialize the transport layer (permissions, etc.)
  Future<void> initialize();

  // Start advertising as a host
  Future<void> startAdvertising(String userName, String strategy);

  // Stop advertising
  Future<void> stopAdvertising();

  // Start discovery as a guest
  Future<void> startDiscovery(String userName, String strategy);

  // Stop discovery
  Future<void> stopDiscovery();

  // Connect to a peer
  Future<void> connect(String deviceId);

  // Disconnect from a peer
  Future<void> disconnect(String deviceId);

  // Send data to a specific peer
  Future<void> sendData(String deviceId, Uint8List data);

  // Send data to all connected peers
  Future<void> broadcastData(Uint8List data);

  // Stream of discovered devices (for guests)
  Stream<List<DiscoveredDevice>> get discoveredDevices;

  // Stream of connection status changes
  Stream<ConnectionChange> get connectionChanges;

  // Stream of received data
  Stream<ReceivedData> get dataReceived;
}

class DiscoveredDevice {
  final String id;
  final String name;
  
  DiscoveredDevice({required this.id, required this.name});
}

class ConnectionChange {
  final String deviceId;
  final ConnectionStatus status;

  ConnectionChange({required this.deviceId, required this.status});
}

class ReceivedData {
  final String senderId;
  final Uint8List data;

  ReceivedData({required this.senderId, required this.data});
}
