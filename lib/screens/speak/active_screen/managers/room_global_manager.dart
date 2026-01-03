import 'dart:async';
import 'dart:io';
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

  Room? _livekitRoom;
  ChatRoom? _roomData;
  bool _isExpanded = false;

  // -- STATE FOR FEATURES --
  RoomActiveFeature _currentFeature = RoomActiveFeature.none;
  String? _featureData;
  bool _isBackCamera = false;
  
  // -- NEW: LOCAL VIEW OVERRIDE --
  // If true, shows the Participant Grid (Tiles) even if a Board is active globally
  bool _isLocalTileView = false; 

  // -- GETTERS --
  Room? get livekitRoom => _livekitRoom;
  ChatRoom? get roomData => _roomData;
  bool get isExpanded => _isExpanded;
  bool get isActive => _livekitRoom != null;

  RoomActiveFeature get activeFeature => _currentFeature;
  String? get activeFeatureData => _featureData;
  bool get isBackCamera => _isBackCamera;
  bool get isLocalTileView => _isLocalTileView; // Expose getter

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Optional
  }

  // -- NEW: TOGGLE LOCAL VIEW --
  void toggleLocalTileView() {
    _isLocalTileView = !_isLocalTileView;
    notifyListeners();
  }

  Future<void> joinRoom(Room room, ChatRoom data) async {
    if (_livekitRoom != null) leaveRoom();
    _livekitRoom = room;
    _roomData = data;
    _isExpanded = true;
    _currentFeature = RoomActiveFeature.none;
    _isBackCamera = false;
    _isLocalTileView = false; // Reset
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
    _isLocalTileView = false;
    notifyListeners();
  }

  void syncFromFirestore(ChatRoom updatedRoom) {
    // Check if feature actually changed to reset local view
    final oldFeature = _roomData?.activeFeature;
    _roomData = updatedRoom;

    if (updatedRoom.activeFeature == 'whiteboard') {
      _currentFeature = RoomActiveFeature.whiteboard;
      _featureData = updatedRoom.activeFeatureData;
      
      // If a NEW whiteboard starts, force user to see it (reset tiles mode)
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
      debugPrint("Switch Camera ignored: $e");
    }
  }

  Future<void> toggleScreenShare() async {
    final local = _livekitRoom?.localParticipant;
    if (local == null) return;

    final isSharing = local.isScreenShareEnabled();

    if (!isSharing) {
      if (Platform.isAndroid) {
        final androidConfig = FlutterBackgroundAndroidConfig(
          notificationTitle: "Screen Sharing Active",
          notificationText: "Linguaflow is sharing your screen.",
          notificationImportance: AndroidNotificationImportance.normal,
          notificationIcon: AndroidResource(
            name: 'ic_launcher',
            defType: 'mipmap',
          ),
        );

        await FlutterBackground.initialize(androidConfig: androidConfig);
        final success = await FlutterBackground.enableBackgroundExecution();
        if (!success) return;
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