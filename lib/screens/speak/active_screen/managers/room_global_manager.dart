import 'dart:async';
import 'package:flutter/material.dart';
import 'package:linguaflow/models/speak/room_member.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:linguaflow/models/speak/speak_models.dart';

class RoomGlobalManager extends ChangeNotifier with WidgetsBindingObserver {
  static final RoomGlobalManager _instance = RoomGlobalManager._internal();
  factory RoomGlobalManager() => _instance;

  RoomGlobalManager._internal() {
    WidgetsBinding.instance.addObserver(this);
  }

  Room? _livekitRoom;
  ChatRoom? _roomData;
  bool _isExpanded = false;

  Room? get livekitRoom => _livekitRoom;
  ChatRoom? get roomData => _roomData;
  bool get isExpanded => _isExpanded;
  bool get isActive => _livekitRoom != null;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {}

  Future<void> joinRoom(Room room, ChatRoom data) async {
    if (_livekitRoom != null) leaveRoom();
    _livekitRoom = room;
    _roomData = data;
    _isExpanded = true;
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
    notifyListeners();
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}