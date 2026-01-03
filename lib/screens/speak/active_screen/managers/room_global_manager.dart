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
      
      // --- FIX IS HERE ---
      // We must save the data (User ID) so the whiteboard knows who to stream.
      // Previously this was set to null, causing the "Empty Document Path" crash.
      _featureData = updatedRoom.activeFeatureData; 
      
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

  // --- FIX 1: SAFER CAMERA SWITCHING ---
  Future<void> switchCamera() async {
    final local = _livekitRoom?.localParticipant;
    if (local == null) return;

    try {
      // CRITICAL: Only get tracks that are strictly CAMERA sources.
      // We must ignore ScreenShare tracks, or the app will crash with "Video capturer not compatible".
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
        notifyListeners();
      }
    } catch (e) {
      // If no camera track is found (e.g. user only has screen share on), ignore.
      debugPrint("Switch Camera ignored: $e");
    }
  }

  // --- FIX 2: ROBUST SCREEN SHARING ---
  Future<void> toggleScreenShare() async {
    final local = _livekitRoom?.localParticipant;
    if (local == null) return;

    final isSharing = local.isScreenShareEnabled();

    if (!isSharing) {
      // STARTING SHARE
      if (Platform.isAndroid) {
        // 1. Config
        final androidConfig = FlutterBackgroundAndroidConfig(
          notificationTitle: "Screen Sharing Active",
          notificationText: "Linguaflow is sharing your screen.",
          notificationImportance: AndroidNotificationImportance.normal,
          notificationIcon: AndroidResource(
            name: 'ic_launcher',
            defType: 'mipmap',
          ),
        );

        // 2. Initialize (ALWAYS required)
        await FlutterBackground.initialize(androidConfig: androidConfig);

        // 3. Enable Background Execution
        final success = await FlutterBackground.enableBackgroundExecution();
        if (!success) {
          debugPrint("Failed to enable background execution.");
          return;
        }
      }

      try {
        await local.setScreenShareEnabled(true, captureScreenAudio: true);
        notifyListeners();
      } catch (e) {
        debugPrint("Screen Share Start Error: $e");
        if (Platform.isAndroid)
          await FlutterBackground.disableBackgroundExecution();
      }
    } else {
      // STOPPING SHARE
      try {
        await local.setScreenShareEnabled(false);
      } catch (e) {
        debugPrint("Screen Share Stop Error: $e");
      }

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