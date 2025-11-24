import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_nearby_connections/flutter_nearby_connections.dart';
import 'transport_service.dart';

class NearbyTransportService implements TransportService {
  final NearbyService _nearbyService;
  late StreamSubscription _stateSubscription;
  late StreamSubscription _dataSubscription;

  final _discoveredDevicesController =
      StreamController<List<DiscoveredDevice>>.broadcast();
  final _connectionChangeController =
      StreamController<ConnectionChange>.broadcast();
  final _dataReceivedController = StreamController<ReceivedData>.broadcast();

  List<Device> _devices = [];

  NearbyTransportService() : _nearbyService = NearbyService();

  @override
  Future<void> initialize() async {
    _stateSubscription = _nearbyService.stateChangedSubscription(
      callback: (devicesList) {
        _devices = devicesList;

        // Update discovered devices
        final discovered = devicesList
            .where((d) => d.state == SessionState.notConnected)
            .map((d) => DiscoveredDevice(id: d.deviceId, name: d.deviceName))
            .toList();
        _discoveredDevicesController.add(discovered);

        // Update connection changes
        for (var device in devicesList) {
          ConnectionStatus status;
          switch (device.state) {
            case SessionState.connected:
              status = ConnectionStatus.connected;
              break;
            case SessionState.connecting:
              status = ConnectionStatus.connecting;
              break;
            case SessionState.notConnected:
              status = ConnectionStatus.disconnected;
              break;
          }
          _connectionChangeController.add(
            ConnectionChange(deviceId: device.deviceId, status: status),
          );
        }
      },
    );

    _dataSubscription = _nearbyService.dataReceivedSubscription(
      callback: (data) {
        final deviceId = data['deviceId'];
        final message = data['message'];

        if (message is String) {
          try {
            final bytes = base64Decode(message);
            _dataReceivedController.add(
              ReceivedData(senderId: deviceId, data: bytes),
            );
          } catch (e) {
            // Ignore non-base64 messages or handle errors
          }
        }
      },
    );
  }

  @override
  Future<void> startAdvertising(String userName, String strategy) async {
    await _nearbyService.init(
      serviceType: 'mpconnshare',
      strategy: Strategy.P2P_CLUSTER,
      deviceName: userName,
      callback: (isRunning) async {
        if (isRunning) {
          await _nearbyService.startAdvertisingPeer();
        }
      },
    );
  }

  @override
  Future<void> stopAdvertising() async {
    await _nearbyService.stopAdvertisingPeer();
  }

  @override
  Future<void> startDiscovery(String userName, String strategy) async {
    await _nearbyService.init(
      serviceType: 'mpconnshare',
      strategy: Strategy.P2P_CLUSTER,
      deviceName: userName,
      callback: (isRunning) async {
        if (isRunning) {
          await _nearbyService.startBrowsingForPeers();
        }
      },
    );
  }

  @override
  Future<void> stopDiscovery() async {
    await _nearbyService.stopBrowsingForPeers();
  }

  @override
  Future<void> connect(String deviceId) async {
    // Find device in list
    try {
      final device = _devices.firstWhere((d) => d.deviceId == deviceId);
      await _nearbyService.invitePeer(
        deviceID: deviceId,
        deviceName: device.deviceName,
      );
    } catch (e) {
      // Device not found
    }
  }

  @override
  Future<void> disconnect(String deviceId) async {
    await _nearbyService.disconnectPeer(deviceID: deviceId);
  }

  @override
  Future<void> sendData(String deviceId, Uint8List data) async {
    final str = base64Encode(data);
    await _nearbyService.sendMessage(deviceId, str);
  }

  @override
  Future<void> broadcastData(Uint8List data) async {
    // Send to all connected devices
    final connectedDevices = _devices.where(
      (d) => d.state == SessionState.connected,
    );
    final str = base64Encode(data);
    for (var device in connectedDevices) {
      await _nearbyService.sendMessage(device.deviceId, str);
    }
  }

  @override
  Stream<List<DiscoveredDevice>> get discoveredDevices =>
      _discoveredDevicesController.stream;

  @override
  Stream<ConnectionChange> get connectionChanges =>
      _connectionChangeController.stream;

  @override
  Stream<ReceivedData> get dataReceived => _dataReceivedController.stream;

  void dispose() {
    _stateSubscription.cancel();
    _dataSubscription.cancel();
    _discoveredDevicesController.close();
    _connectionChangeController.close();
    _dataReceivedController.close();
  }
}
