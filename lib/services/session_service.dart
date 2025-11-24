import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../models/session.dart';
import '../models/photo_item.dart';
import 'transport_service.dart';
import 'nearby_transport_service.dart';
import 'photo_service.dart';

class SessionService extends ChangeNotifier {
  final TransportService _transport;
  final PhotoService _photoService;
  Session _session;
  Timer? _privacyBufferTimer;
  bool _isBufferActive = false;
  PhotoItem? _pendingPhoto;

  // Current photo being shown (or last shown)
  PhotoItem? _currentPhoto;

  // Received photo data (for guest)
  Uint8List? _receivedImageData;

  SessionService({TransportService? transport, PhotoService? photoService})
    : _transport = transport ?? NearbyTransportService(),
      _photoService = photoService ?? PhotoService(),
      _session = const Session(id: '', hostId: '') {
    _initTransport();
  }

  Session get session => _session;
  bool get isBufferActive => _isBufferActive;
  PhotoItem? get currentPhoto => _currentPhoto;
  Uint8List? get receivedImageData => _receivedImageData;

  List<DiscoveredDevice> _discoveredDevices = [];
  List<DiscoveredDevice> get discoveredDevices => _discoveredDevices;

  Future<void> _initTransport() async {
    await _transport.initialize();

    _transport.discoveredDevices.listen((devices) {
      _discoveredDevices = devices;
      notifyListeners();
    });

    _transport.connectionChanges.listen((change) {
      switch (change.status) {
        case ConnectionStatus.connecting:
          _session = _session.copyWith(state: SessionState.connecting);
          notifyListeners();
          break;
        case ConnectionStatus.connected:
          final currentPeers = List<String>.from(_session.peerIds);
          if (!currentPeers.contains(change.deviceId)) {
            currentPeers.add(change.deviceId);
          }
          _session = _session.copyWith(
            peerIds: currentPeers,
            state: SessionState.connected,
          );
          notifyListeners();
          break;
        case ConnectionStatus.disconnected:
          final currentPeers = List<String>.from(_session.peerIds);
          currentPeers.remove(change.deviceId);
          final nextState = currentPeers.isNotEmpty
              ? SessionState.connected
              : (_session.isHost
                    ? SessionState.advertising
                    : SessionState.discovering);
          _session = _session.copyWith(peerIds: currentPeers, state: nextState);
          notifyListeners();
          break;
        case ConnectionStatus.error:
          _session = _session.copyWith(state: SessionState.ended);
          notifyListeners();
          break;
      }
    });

    _transport.dataReceived.listen((data) {
      // Handle received data (photo bytes)
      // In a real app, we might send metadata first, then chunks.
      // For simplicity, assuming small enough images or handled by library for now.
      _receivedImageData = data.data;
      notifyListeners();
    });
  }

  Future<String> _getDeviceName() async {
    final deviceInfo = DeviceInfoPlugin();
    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.model;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return iosInfo.name;
    }
    return 'Flutter Device';
  }

  Future<void> startHost() async {
    final deviceName = await _getDeviceName();
    final sessionId = const Uuid().v4();
    _session = Session(
      id: sessionId,
      hostId: 'local', // We are host
      state: SessionState.advertising,
      isHost: true,
    );
    notifyListeners();
    await _transport.startAdvertising(deviceName, 'P2P_CLUSTER');
  }

  Future<void> startGuest() async {
    final deviceName = await _getDeviceName();
    _session = _session.copyWith(
      state: SessionState.discovering,
      isHost: false,
    );
    notifyListeners();
    await _transport.startDiscovery(deviceName, 'P2P_CLUSTER');
  }

  Future<void> joinSession(String deviceId) async {
    _session = _session.copyWith(state: SessionState.connecting);
    notifyListeners();
    await _transport.connect(deviceId);
    // Assume connected for now, listener will update
  }

  Future<void> stopSession() async {
    if (_session.isHost) {
      await _transport.stopAdvertising();
    } else {
      await _transport.stopDiscovery();
    }
    // Disconnect all
    for (var peer in _session.peerIds) {
      await _transport.disconnect(peer);
    }
    _session = const Session(id: '', hostId: '', state: SessionState.ended);
    _currentPhoto = null;
    _receivedImageData = null;
    notifyListeners();
  }

  // Host: Select a photo to share (starts buffer)
  void selectPhoto(PhotoItem photo) {
    if (!_session.isHost) return;

    _pendingPhoto = photo;
    _currentPhoto = photo; // Show locally immediately
    _isBufferActive = true;
    notifyListeners();

    _privacyBufferTimer?.cancel();
    _privacyBufferTimer = Timer(const Duration(seconds: 2), () {
      _sharePendingPhoto();
    });
  }

  // Host: Cancel sharing during buffer
  void cancelShare() {
    _privacyBufferTimer?.cancel();
    _isBufferActive = false;
    _pendingPhoto = null;
    notifyListeners();
  }

  Future<void> _sharePendingPhoto() async {
    _isBufferActive = false;
    notifyListeners();

    if (_pendingPhoto != null) {
      // Fetch bytes (thumbnail or compressed)
      // Using a reasonable size for P2P transfer (e.g., 1080p or similar, here using 1000x1000 thumbnail for speed)
      final bytes = await _photoService.getThumbnail(
        _pendingPhoto!.id,
        width: 1080,
        height: 1920,
      );
      if (bytes != null) {
        await sendImageBytes(bytes);
      }
    }
  }

  // Method to actually send data (called after buffer)
  Future<void> sendImageBytes(Uint8List bytes) async {
    if (_session.isHost) {
      await _transport.broadcastData(bytes);
    }
  }
}
