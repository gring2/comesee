import 'dart:async';
import 'dart:convert';

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
  int _bufferSecondsRemaining = 0;
  bool _showSharedConfirmation = false;
  PhotoItem? _pendingPhoto;
  PhotoItem? _lastSharedPhoto;

  // Current photo being shown (or last shown)
  PhotoItem? _currentPhoto;

  // Received photo data (for guest)
  Uint8List? _receivedImageData;
  Uint8List? _pendingReceivedImageData;
  bool _waitingForShowCommand = false;

  SessionService({TransportService? transport, PhotoService? photoService})
      : _transport = transport ?? NearbyTransportService(),
        _photoService = photoService ?? PhotoService(),
        _session = const Session(id: '', hostId: '') {
    _initTransport();
  }

  Session get session => _session;
  bool get isBufferActive => _isBufferActive;
  int get bufferSecondsRemaining => _bufferSecondsRemaining;
  bool get showSharedConfirmation => _showSharedConfirmation;
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
          
          // Sync photos to new peer
          if (_session.isHost) {
            if (_lastSharedPhoto != null) {
              _syncPhotoToPeer(change.deviceId, _lastSharedPhoto!, show: true);
            }
            if (_isBufferActive && _currentPhoto != null && _currentPhoto != _lastSharedPhoto) {
              _syncPhotoToPeer(change.deviceId, _currentPhoto!, show: false);
            }
          }
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
      try {
        final String jsonString = utf8.decode(data.data);
        final Map<String, dynamic> message = jsonDecode(jsonString);


        switch (message['type']) {
          case 'preload':
             final String base64Image = message['data'];
             _pendingReceivedImageData = base64Decode(base64Image);
             
             // If we already received the show command, display immediately
             if (_waitingForShowCommand) {
               _receivedImageData = _pendingReceivedImageData;
               _pendingReceivedImageData = null;
               _waitingForShowCommand = false;
               notifyListeners();
             }
             break;
          case 'show':
             if (_pendingReceivedImageData != null) {
               _receivedImageData = _pendingReceivedImageData;
               _pendingReceivedImageData = null;
               _waitingForShowCommand = false;
               notifyListeners();
             } else {
               // Data hasn't arrived yet, wait for it
               _waitingForShowCommand = true;
             }
             break;
          case 'cancel':
             _pendingReceivedImageData = null;
             _waitingForShowCommand = false;
             break;
        }
      } catch (e) {
        // Fallback or ignore
      }
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

    _privacyBufferTimer?.cancel();

    _pendingPhoto = photo;
    _currentPhoto = photo; // Show locally immediately
    _isBufferActive = true;
    _showSharedConfirmation = false;
    _bufferSecondsRemaining = 2;
    notifyListeners();

    // Start pre-loading immediately
    _preloadPhoto(photo);

    _privacyBufferTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _bufferSecondsRemaining--;
      if (_bufferSecondsRemaining <= 0) {
        timer.cancel();
        _confirmShare();
      } else {
        notifyListeners();
      }
    });
  }

  // Host: Cancel sharing during buffer
  void cancelShare() {
    _privacyBufferTimer?.cancel();
    _isBufferActive = false;
    _showSharedConfirmation = false;
    _pendingPhoto = null;
    notifyListeners();

    final message = jsonEncode({'type': 'cancel'});
    _transport.broadcastData(utf8.encode(message));
  }

  Future<void> _preloadPhoto(PhotoItem photo) async {
    // Reduced size for faster P2P transfer (720p is usually sufficient for phone screens)
    final bytes = await _photoService.getThumbnail(
      photo.id,
      width: 720,
      height: 1280,
    );
    if (bytes != null) {
      final message = jsonEncode({
        'type': 'preload',
        'data': base64Encode(bytes),
      });
      await _transport.broadcastData(utf8.encode(message));
    }
  }

  Future<void> _confirmShare() async {
    _isBufferActive = false;
    _showSharedConfirmation = true;
    _lastSharedPhoto = _currentPhoto;
    notifyListeners();
    
    // Hide "Shared" confirmation after 1 second
    Future.delayed(const Duration(seconds: 1), () {
      if (_showSharedConfirmation) {
        _showSharedConfirmation = false;
        notifyListeners();
      }
    });

    final message = jsonEncode({'type': 'show'});
    await _transport.broadcastData(utf8.encode(message));
  }

  Future<void> _syncPhotoToPeer(String peerId, PhotoItem photo, {required bool show}) async {
    final bytes = await _photoService.getThumbnail(
      photo.id,
      width: 720,
      height: 1280,
    );
    if (bytes != null) {
      final preloadMsg = jsonEncode({
        'type': 'preload',
        'data': base64Encode(bytes),
      });
      await _transport.sendData(peerId, utf8.encode(preloadMsg));
      
      if (show) {
        final showMsg = jsonEncode({'type': 'show'});
        await _transport.sendData(peerId, utf8.encode(showMsg));
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
