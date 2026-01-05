import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:linguaflow/models/speak/room_member.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:linguaflow/models/speak/speak_models.dart';

enum RoomActiveFeature { none, whiteboard, youtube }

class RoomGlobalManager extends ChangeNotifier with WidgetsBindingObserver {
  static final RoomGlobalManager _instance = RoomGlobalManager._internal();
  factory RoomGlobalManager() => _instance;

  RoomGlobalManager._internal() {
    WidgetsBinding.instance.addObserver(this);
  }

  // Core room state
  Room? _livekitRoom;
  ChatRoom? _roomData;
  bool _isExpanded = false;

  // Feature state
  RoomActiveFeature _currentFeature = RoomActiveFeature.none;
  String? _featureData;
  bool _isBackCamera = false;
  bool _isLocalTileView = false;

  // Screen sharing state management
  bool _isScreenSharing = false;
  bool _wasScreenSharingBeforeBackground = false;
  bool _isScreenShareRestarting = false;
  Timer? _screenShareRetryTimer;
  int _screenShareRetryAttempts = 0;
  static const int _maxRetryAttempts = 3;
  static const Duration _retryDelay = Duration(seconds: 2);

  // Foreground service state
  bool _isForegroundServiceRunning = false;

  // Getters
  Room? get livekitRoom => _livekitRoom;
  ChatRoom? get roomData => _roomData;
  bool get isExpanded => _isExpanded;
  bool get isActive => _livekitRoom != null;
  RoomActiveFeature get activeFeature => _currentFeature;
  String? get activeFeatureData => _featureData;
  bool get isBackCamera => _isBackCamera;
  bool get isLocalTileView => _isLocalTileView;
  bool get isScreenSharing => _isScreenSharing;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (kIsWeb || !Platform.isAndroid) return;

    final local = _livekitRoom?.localParticipant;
    if (local == null) return;

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _handleAppGoingToBackground(local);
        break;

      case AppLifecycleState.resumed:
        _handleAppReturningToForeground();
        break;

      case AppLifecycleState.detached:
        // App is being closed - cleanup
        _cleanupScreenShare();
        break;

      default:
        break;
    }
  }

  /// Handle app going to background
  void _handleAppGoingToBackground(LocalParticipant local) {
    if (local.isScreenShareEnabled()) {
      _wasScreenSharingBeforeBackground = true;
      debugPrint("📱 App backgrounded - saving screen share state");
      // Don't stop immediately - let Android handle it naturally
    }
  }

  /// Handle app returning to foreground
  void _handleAppReturningToForeground() {
    if (_wasScreenSharingBeforeBackground && !_isScreenShareRestarting) {
      debugPrint("📱 App resumed - restarting screen share");
      _wasScreenSharingBeforeBackground = false;

      // Give the app time to fully resume before restarting
      Future.delayed(const Duration(milliseconds: 800), () {
        if (_livekitRoom?.localParticipant != null) {
          _restartScreenShareWithRetry();
        }
      });
    }
  }

  /// Restart screen share with retry logic
  Future<void> _restartScreenShareWithRetry() async {
    if (_isScreenShareRestarting) {
      debugPrint("⏳ Screen share restart already in progress");
      return;
    }

    _isScreenShareRestarting = true;
    _screenShareRetryAttempts = 0;

    bool success = await _attemptScreenShareRestart();

    if (!success && _screenShareRetryAttempts < _maxRetryAttempts) {
      debugPrint("🔄 Scheduling screen share retry...");
      _scheduleScreenShareRetry();
    } else {
      _isScreenShareRestarting = false;
      if (!success) {
        debugPrint(
          "❌ Failed to restart screen share after $_maxRetryAttempts attempts",
        );
      }
    }
  }

  /// Attempt to restart screen sharing
  Future<bool> _attemptScreenShareRestart() async {
    try {
      final local = _livekitRoom?.localParticipant;
      if (local == null) return false;

      debugPrint(
        "🔄 Attempting screen share restart (attempt ${_screenShareRetryAttempts + 1})",
      );

      // Ensure foreground service is running
      if (!_isForegroundServiceRunning) {
        bool serviceStarted = await _startForegroundService();
        if (!serviceStarted) {
          debugPrint("❌ Failed to start foreground service");
          return false;
        }
      }

      // Restart screen sharing
      await local.setScreenShareEnabled(true, captureScreenAudio: true);

      _isScreenSharing = true;
      _screenShareRetryAttempts = 0;
      _isScreenShareRestarting = false;

      debugPrint("✅ Screen share restarted successfully");
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("❌ Screen share restart failed: $e");
      _screenShareRetryAttempts++;
      return false;
    }
  }

  /// Schedule a retry for screen share restart
  void _scheduleScreenShareRetry() {
    _screenShareRetryTimer?.cancel();
    _screenShareRetryTimer = Timer(_retryDelay, () async {
      if (_screenShareRetryAttempts < _maxRetryAttempts) {
        await _attemptScreenShareRestart();

        if (!_isScreenSharing &&
            _screenShareRetryAttempts < _maxRetryAttempts) {
          _scheduleScreenShareRetry();
        } else {
          _isScreenShareRestarting = false;
        }
      } else {
        _isScreenShareRestarting = false;
      }
    });
  }

  /// Start Android foreground service for screen sharing
  Future<bool> _startForegroundService() async {
    if (kIsWeb || !Platform.isAndroid) return true;

    try {
      // Check if already running
      if (_isForegroundServiceRunning) {
        debugPrint("✅ Foreground service already running");
        return true;
      }

      final androidConfig = FlutterBackgroundAndroidConfig(
        notificationTitle: "Screen Sharing Active",
        notificationText: "Linguaflow is sharing your screen",
        notificationImportance: AndroidNotificationImportance.normal,
        notificationIcon: AndroidResource(
          name: 'ic_launcher',
          defType: 'mipmap',
        ),
        enableWifiLock: true, // Keep WiFi active
      );

      bool hasPermissions = await FlutterBackground.hasPermissions;
      if (!hasPermissions) {
        debugPrint("⚠️ Background permissions not granted");
        return false;
      }

      bool success = await FlutterBackground.initialize(
        androidConfig: androidConfig,
      );

      if (success) {
        await FlutterBackground.enableBackgroundExecution();
        _isForegroundServiceRunning = true;
        debugPrint("✅ Foreground service started");
        return true;
      } else {
        debugPrint("❌ Failed to initialize foreground service");
        return false;
      }
    } catch (e) {
      debugPrint("❌ Error starting foreground service: $e");
      return false;
    }
  }

  /// Stop Android foreground service
  Future<void> _stopForegroundService() async {
    if (kIsWeb || !Platform.isAndroid) return;

    try {
      if (await FlutterBackground.isBackgroundExecutionEnabled) {
        await FlutterBackground.disableBackgroundExecution();
        _isForegroundServiceRunning = false;
        debugPrint("✅ Foreground service stopped");
      }
    } catch (e) {
      debugPrint("❌ Error stopping foreground service: $e");
    }
  }

  /// Clean up screen share state
  Future<void> _cleanupScreenShare() async {
    _screenShareRetryTimer?.cancel();
    _screenShareRetryTimer = null;
    _isScreenShareRestarting = false;
    _wasScreenSharingBeforeBackground = false;
    _screenShareRetryAttempts = 0;

    await _stopForegroundService();
  }

  /// Toggle local tile view
  void toggleLocalTileView() {
    _isLocalTileView = !_isLocalTileView;
    notifyListeners();
  }

  /// Join a LiveKit room
  Future<void> joinRoom(Room room, ChatRoom data) async {
    if (_livekitRoom != null) await leaveRoom();

    _livekitRoom = room;
    _roomData = data;
    _isExpanded = true;
    _currentFeature = RoomActiveFeature.none;
    _isBackCamera = false;
    _isLocalTileView = false;
    _isScreenSharing = false;
    _wasScreenSharingBeforeBackground = false;

    notifyListeners();
    debugPrint("✅ Joined room: ${data.title}");
  }

  /// Expand room view
  void expand() {
    _isExpanded = true;
    notifyListeners();
  }

  /// Collapse room view
  void collapse() {
    _isExpanded = false;
    notifyListeners();
  }

  /// Leave the current room
  Future<void> leaveRoom() async {
    debugPrint("🚪 Leaving room...");

    // Stop screen sharing if active
    if (_isScreenSharing) {
      await toggleScreenShare();
    }

    // Disconnect from LiveKit
    if (_livekitRoom != null) {
      await _livekitRoom!.disconnect();
    }

    // Cleanup
    await _cleanupScreenShare();

    _livekitRoom = null;
    _roomData = null;
    _isExpanded = false;
    _currentFeature = RoomActiveFeature.none;
    _featureData = null;
    _isLocalTileView = false;
    _isScreenSharing = false;

    notifyListeners();
    debugPrint("✅ Left room successfully");
  }

  /// Sync room data from Firestore
  void syncFromFirestore(ChatRoom updatedRoom) {
    final oldFeature = _roomData?.activeFeature;
    _roomData = updatedRoom;

    if (updatedRoom.activeFeature == 'whiteboard') {
      _currentFeature = RoomActiveFeature.whiteboard;
      _featureData = updatedRoom.activeFeatureData;

      if (oldFeature != 'whiteboard') {
        _isLocalTileView = false;
      }
    } else if (updatedRoom.activeFeature == 'youtube') {
      _currentFeature = RoomActiveFeature.youtube;
      _featureData = updatedRoom.activeFeatureData;

      if (oldFeature != 'youtube') {
        _isLocalTileView = false;
      }
    } else {
      _currentFeature = RoomActiveFeature.none;
      _featureData = null;
      _isLocalTileView = false;
    }

    notifyListeners();
  }

  /// Toggle microphone
  Future<void> toggleMic() async {
    final local = _livekitRoom?.localParticipant;
    if (local != null) {
      await local.setMicrophoneEnabled(!local.isMicrophoneEnabled());
      debugPrint(
        "🎤 Microphone ${local.isMicrophoneEnabled() ? 'enabled' : 'disabled'}",
      );
      notifyListeners();
    }
  }

  /// Toggle camera
  Future<void> toggleCamera() async {
    final local = _livekitRoom?.localParticipant;
    if (local != null) {
      await local.setCameraEnabled(!local.isCameraEnabled());
      debugPrint(
        "📹 Camera ${local.isCameraEnabled() ? 'enabled' : 'disabled'}",
      );
      notifyListeners();
    }
  }

  /// Switch between front and back camera
  Future<void> switchCamera() async {
    final local = _livekitRoom?.localParticipant;
    if (local == null) return;

    try {
      final trackPublication = local.videoTrackPublications.firstWhere(
        (pub) => pub.source == TrackSource.camera,
        orElse: () => throw "No Camera Track found",
      );

      final track = trackPublication.track;

      if (track is LocalVideoTrack) {
        _isBackCamera = !_isBackCamera;
        final newPosition = _isBackCamera
            ? CameraPosition.back
            : CameraPosition.front;

        await track.restartTrack(
          CameraCaptureOptions(
            cameraPosition: newPosition,
            params: const VideoParameters(
              dimensions: VideoDimensions(1280, 720),
              encoding: VideoEncoding(
                maxBitrate: 1700 * 1000,
                maxFramerate: 30,
              ),
            ),
          ),
        );

        debugPrint("📹 Switched to ${_isBackCamera ? 'back' : 'front'} camera");
        notifyListeners();
      }
    } catch (e) {
      debugPrint("❌ Switch Camera error: $e");
    }
  }

  /// Toggle screen sharing with robust error handling
  Future<void> toggleScreenShare() async {
    final local = _livekitRoom?.localParticipant;
    if (local == null) {
      debugPrint("⚠️ Cannot toggle screen share - no local participant");
      return;
    }

    try {
      if (!_isScreenSharing) {
        // START SCREEN SHARING
        debugPrint("🖥️ Starting screen share...");

        // Start foreground service first (Android only)
        if (!kIsWeb && Platform.isAndroid) {
          bool serviceStarted = await _startForegroundService();
          if (!serviceStarted) {
            debugPrint(
              "❌ Cannot start screen share - foreground service failed",
            );
            return;
          }
        }

        // Start screen sharing with optimized settings
        await local.setScreenShareEnabled(
          true,
          captureScreenAudio: true,
          // Add screen capture options for better compatibility
          // useH264HardwareEncoder: true,
        );

        _isScreenSharing = true;
        _screenShareRetryAttempts = 0;

        debugPrint("✅ Screen sharing started");

        // CRITICAL: Give the track a moment to initialize
        await Future.delayed(const Duration(milliseconds: 500));

        // Verify track is actually producing frames
        final screenPub = local.videoTrackPublications.firstWhere(
          (pub) => pub.source == TrackSource.screenShareVideo,
          orElse: () => throw "Screen share track not found after starting",
        );

        debugPrint("📊 Screen share track state:");
        debugPrint("   - SID: ${screenPub.sid}");
        debugPrint("   - Track: ${screenPub.track}");
        debugPrint("   - Subscribed: ${screenPub.subscribed}");
        debugPrint("   - Muted: ${screenPub.muted}");
      } else {
        // STOP SCREEN SHARING
        debugPrint("🖥️ Stopping screen share...");

        await local.setScreenShareEnabled(false);
        _isScreenSharing = false;
        _wasScreenSharingBeforeBackground = false;

        // Stop foreground service (Android only)
        await _stopForegroundService();

        debugPrint("✅ Screen sharing stopped");
      }

      notifyListeners();
    } catch (e) {
      debugPrint("❌ Screen Share Error: $e");
      _isScreenSharing = false;

      // Cleanup on error
      if (!kIsWeb && Platform.isAndroid) {
        await _stopForegroundService();
      }

      notifyListeners();

      // Rethrow to allow UI to show error message
      rethrow;
    }
  }

  /// Update room members
  void updateMembers(List<RoomMember> newMembers) {
    if (_roomData != null) {
      _roomData = _roomData!.copyWith(
        members: newMembers,
        memberCount: newMembers.length,
      );
      notifyListeners();
    }
  }

  /// Get screen share track for display
  VideoTrack? getScreenShareTrack() {
    final local = _livekitRoom?.localParticipant;
    if (local == null) return null;

    try {
      final screenPub = local.videoTrackPublications.firstWhere(
        (pub) => pub.source == TrackSource.screenShareVideo,
        orElse: () => throw "No screen share track",
      );
      return screenPub.track as VideoTrack?;
    } catch (e) {
      return null;
    }
  }

  @override
  void dispose() {
    debugPrint("🧹 Disposing RoomGlobalManager");
    _screenShareRetryTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
