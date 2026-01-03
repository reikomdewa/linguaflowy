import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:linguaflow/models/speak/room_member.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:linguaflow/models/speak/speak_models.dart';

// Enum to track what is currently overlaying the video grid
enum RoomActiveFeature { none, whiteboard, youtube }

class RoomGlobalManager extends ChangeNotifier with WidgetsBindingObserver {
  static final RoomGlobalManager _instance = RoomGlobalManager._internal();
  factory RoomGlobalManager() => _instance;

  RoomGlobalManager._internal() {
    WidgetsBinding.instance.addObserver(this);
  }

  Room? _livekitRoom;
  ChatRoom? _roomData;
  bool _isExpanded = false;

  // -- STATE FOR FEATURES --
  RoomActiveFeature _currentFeature = RoomActiveFeature.none;
  String? _featureData;
  bool _isBackCamera = false; // Tracks if we are using back camera

  // -- GETTERS --
  Room? get livekitRoom => _livekitRoom;
  ChatRoom? get roomData => _roomData;
  bool get isExpanded => _isExpanded;
  bool get isActive => _livekitRoom != null;

  RoomActiveFeature get activeFeature => _currentFeature;
  String? get activeFeatureData => _featureData;
  bool get isBackCamera => _isBackCamera;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Optional: Handle background state if needed
  }

  Future<void> joinRoom(Room room, ChatRoom data) async {
    if (_livekitRoom != null) leaveRoom();
    _livekitRoom = room;
    _roomData = data;
    _isExpanded = true;
    _currentFeature = RoomActiveFeature.none;
    _isBackCamera = false;
    notifyListeners();
  }

  void expand() {
    _isExpanded = true;
    notifyListeners();
  }

  void collapse() {
    _isExpanded = false;
    notifyListeners();
  }

  Future<void> leaveRoom() async {
    if (_livekitRoom != null) {
      await _livekitRoom!.disconnect();
    }
    _livekitRoom = null;
    _roomData = null;
    _isExpanded = false;
    _currentFeature = RoomActiveFeature.none;
    _featureData = null;
    notifyListeners();
  }

  // -- FIRESTORE SYNC --
  // This is called by LiveRoomOverlay when Firestore doc updates
  void syncFromFirestore(ChatRoom updatedRoom) {
    _roomData = updatedRoom;

    // 1. Sync Active Feature
    if (updatedRoom.activeFeature == 'whiteboard') {
      _currentFeature = RoomActiveFeature.whiteboard;
      _featureData = null;
    } else if (updatedRoom.activeFeature == 'youtube') {
      _currentFeature = RoomActiveFeature.youtube;
      _featureData = updatedRoom.activeFeatureData;
    } else {
      _currentFeature = RoomActiveFeature.none;
      _featureData = null;
    }

    notifyListeners();
  }

  // -- MEDIA CONTROLS --

  Future<void> toggleMic() async {
    final local = _livekitRoom?.localParticipant;
    if (local != null) {
      await local.setMicrophoneEnabled(!local.isMicrophoneEnabled());
      notifyListeners();
    }
  }

  Future<void> toggleCamera() async {
    final local = _livekitRoom?.localParticipant;
    if (local != null) {
      await local.setCameraEnabled(!local.isCameraEnabled());
      notifyListeners();
    }
  }

  Future<void> switchCamera() async {
    final local = _livekitRoom?.localParticipant;
    if (local == null) return;

    try {
      // 1. Get the current video track
      final trackPublication = local.videoTrackPublications.firstOrNull;
      final track = trackPublication?.track;

      if (track is LocalVideoTrack) {
        // 2. Toggle the boolean state
        _isBackCamera = !_isBackCamera;

        // 3. Determine the new camera position
        final newPosition = _isBackCamera
            ? CameraPosition.back
            : CameraPosition.front;

        // 4. Restart the track with new options
        await track.restartTrack(
          CameraCaptureOptions(
            cameraPosition: newPosition,
            // FIX IS HERE: Removed 'const' before VideoParametersPresets
            params: VideoParametersPresets.h720_169,
          ),
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error switching camera: $e");
      // Revert state on failure
      _isBackCamera = !_isBackCamera;
    }
  }

  Future<void> toggleScreenShare() async {
    final local = _livekitRoom?.localParticipant;
    if (local == null) return;

    final isSharing = local.isScreenShareEnabled();

    if (!isSharing) {
      // --- START SHARING ---

      // 1. Android Specific Setup (Prevent App Kill)
      if (Platform.isAndroid) {
        final androidConfig = FlutterBackgroundAndroidConfig(
          notificationTitle: "Screen Sharing",
          notificationText: "Live Room is active in the background.",
          notificationImportance: AndroidNotificationImportance.normal,
          notificationIcon: AndroidResource(
            name: 'ic_launcher',
            defType: 'mipmap',
          ),
        );

        // FIX: Always Initialize, regardless of current permission state
        bool initSuccess = await FlutterBackground.initialize(
          androidConfig: androidConfig,
        );

        if (initSuccess) {
          try {
            // Enable the background service
            bool enabled = await FlutterBackground.enableBackgroundExecution();
            if (!enabled) {
              debugPrint("Failed to enable background execution");
              return; // Stop if we can't run in background
            }
          } catch (e) {
            debugPrint("Background execution error: $e");
            return;
          }
        } else {
          debugPrint("FlutterBackground initialization failed");
          return;
        }
      }

      // 2. Start LiveKit Sharing
      try {
        await local.setScreenShareEnabled(true, captureScreenAudio: true);
        notifyListeners();
      } catch (e) {
        debugPrint("Error starting screen share: $e");
        // Cleanup if LiveKit fails
        if (Platform.isAndroid)
          await FlutterBackground.disableBackgroundExecution();
      }
    } else {
      // --- STOP SHARING ---
      try {
        await local.setScreenShareEnabled(false);
      } catch (e) {
        debugPrint("Error stopping screen share: $e");
      }

      // Disable background service to save battery
      if (Platform.isAndroid) {
        await FlutterBackground.disableBackgroundExecution();
      }
      notifyListeners();
    }
  }

  void updateMembers(List<RoomMember> newMembers) {
    if (_roomData != null) {
      _roomData = _roomData!.copyWith(
        members: newMembers,
        memberCount: newMembers.length,
      );
      notifyListeners();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
