// --- 1. User Management Sheet (Mutes/Bans) ---
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:linguaflow/core/globals.dart';
import 'package:linguaflow/models/speak/room_member.dart';
import 'package:linguaflow/models/speak/speak_models.dart';
import 'package:linguaflow/screens/speak/active_screen/managers/room_global_manager.dart';
import 'package:linguaflow/screens/speak/active_screen/widgets/overlays/full_screen_participant.dart';
import 'package:linguaflow/screens/speak/active_screen/widgets/overlays/leave_comfirm_dialog.dart';
import 'package:linguaflow/screens/speak/active_screen/widgets/sheets/board_requests_sheet.dart';
import 'package:linguaflow/screens/speak/active_screen/widgets/sheets/youtube_requests_sheet.dart'; // Ensure this exists
import 'package:linguaflow/screens/speak/active_screen/widgets/youtube_input_dialog.dart'; // Ensure this exists
import 'package:livekit_client/livekit_client.dart';

import 'package:linguaflow/screens/speak/widgets/sheets/room_chat_sheet.dart';
import 'package:linguaflow/services/speak/chat_service.dart';

// BLOC EVENTS
import 'package:linguaflow/blocs/speak/room/room_bloc.dart';
import 'package:linguaflow/blocs/speak/room/room_event.dart' hide RoomEvent;

// ==========================================
// ==========================================
//  HELPER STACK WIDGETS
// ==========================================

// --- 1. User Management Sheet (Mutes/Bans) ---
class UserManagementSheetStack extends StatelessWidget {
  final bool isBanning;
  final List<RoomMember> members;
  final List<Participant> liveParticipants; // <--- NEW: Pass live participants
  final String roomId;
  final VoidCallback onClose;
  final RoomGlobalManager manager;

  const UserManagementSheetStack({
    super.key,
    required this.isBanning,
    required this.members,
    required this.liveParticipants, // <--- NEW
    required this.roomId,
    required this.onClose,
    required this.manager,
  });

  @override
  Widget build(BuildContext context) {
    // Filter out yourself
    final currentUserUid = FirebaseAuth.instance.currentUser?.uid;
    final guests = members.where((m) => m.uid != currentUserUid).toList();

    return Align(
      alignment: Alignment.bottomCenter,
      child: Material(
        color: const Color(0xFF1E1E1E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(16),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // HEADER
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 40),
                  Text(
                    isBanning ? "Ban Users" : "Manage Audio",
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: onClose,
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (guests.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text("No guests in the room.", style: TextStyle(color: Colors.white54)),
                ),

              // LIST
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: guests.length,
                  itemBuilder: (context, index) {
                    final member = guests[index];
                    
                    // FIND THE MATCHING PARTICIPANT FROM THE PASSED LIST
                    Participant? participant;
                    try {
                       participant = liveParticipants.firstWhere(
                         (p) => p.identity == member.uid,
                         // No fallback here to keep it null if not found
                       );
                    } catch (_) {}

                    return _UserAudioTile(
                      key: ValueKey(member.uid),
                      member: member,
                      participant: participant, // Pass the found object directly
                      isBanning: isBanning,
                      roomId: roomId,
                      onCloseSheet: onClose,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- PRIVATE HELPER: AUDIO TILE ---
class _UserAudioTile extends StatefulWidget {
  final RoomMember member;
  final Participant? participant; // Direct reference
  final bool isBanning;
  final String roomId;
  final VoidCallback onCloseSheet;

  const _UserAudioTile({
    super.key,
    required this.member,
    required this.participant,
    required this.isBanning,
    required this.roomId,
    required this.onCloseSheet,
  });

  @override
  State<_UserAudioTile> createState() => _UserAudioTileState();
}

class _UserAudioTileState extends State<_UserAudioTile> {
  @override
  void initState() {
    super.initState();
    // Listen to changes on the specific participant object
    widget.participant?.addListener(_onParticipantChanged);
  }

  @override
  void didUpdateWidget(covariant _UserAudioTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.participant != widget.participant) {
      oldWidget.participant?.removeListener(_onParticipantChanged);
      widget.participant?.addListener(_onParticipantChanged);
    }
  }

  @override
  void dispose() {
    widget.participant?.removeListener(_onParticipantChanged);
    super.dispose();
  }

  void _onParticipantChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.participant;
    final bool isConnected = p != null;
    
    // Exact logic from ParticipantTile
    bool isMicOn = false;
    bool isSpeaking = false;

    if (p != null) {
      isMicOn = p.isMicrophoneEnabled();
      isSpeaking = p.isSpeaking;
    }

    String statusText;
    Color statusColor;

    if (!isConnected) {
      statusText = "Not Connected";
      statusColor = Colors.grey;
    } else if (isSpeaking) {
      statusText = "Speaking...";
      statusColor = Colors.greenAccent;
    } else if (isMicOn) {
      statusText = "Mic On";
      statusColor = Colors.green;
    } else {
      statusText = "Muted";
      statusColor = Colors.redAccent;
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundImage: (widget.member.avatarUrl != null && widget.member.avatarUrl!.isNotEmpty)
            ? NetworkImage(widget.member.avatarUrl!)
            : null,
        backgroundColor: Colors.grey[800],
        child: (widget.member.avatarUrl == null || widget.member.avatarUrl!.isEmpty)
            ? const Icon(Icons.person, color: Colors.white70)
            : null,
      ),
      title: Text(
        widget.member.displayName ?? "Guest",
        style: const TextStyle(color: Colors.white),
      ),
      subtitle: !widget.isBanning
          ? Row(
              children: [
                Icon(Icons.circle, size: 8, color: statusColor),
                const SizedBox(width: 6),
                Text(statusText, style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            )
          : null,
      trailing: IconButton(
        icon: Icon(
          widget.isBanning
              ? Icons.gavel
              : (isMicOn ? Icons.mic : Icons.mic_off),
          color: widget.isBanning
              ? Colors.redAccent
              : (isMicOn ? Colors.green : Colors.grey),
        ),
        onPressed: () {
          if (widget.isBanning) {
            context.read<RoomBloc>().add(
              KickUserEvent(roomId: widget.roomId, userId: widget.member.uid)
            );
            widget.onCloseSheet();
          } else {
            // Mute logic place holder
          }
        },
      ),
    );
  }
}

// --- 2. Edit Room Dialog (Stack Version) ---
class EditRoomDialogStack extends StatefulWidget {
  final ChatRoom room;
  final VoidCallback onClose;
  const EditRoomDialogStack({super.key, required this.room, required this.onClose});

  @override
  State<EditRoomDialogStack> createState() => _EditRoomDialogStackState();
}

class _EditRoomDialogStackState extends State<EditRoomDialogStack> {
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.room.title);
    _descCtrl = TextEditingController(text: widget.room.description);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(12),
        elevation: 10,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Edit Room", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              TextField(
                controller: _titleCtrl, 
                style: const TextStyle(color: Colors.white), 
                decoration: const InputDecoration(labelText: "Topic", labelStyle: TextStyle(color: Colors.white54))
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _descCtrl, 
                style: const TextStyle(color: Colors.white), 
                decoration: const InputDecoration(labelText: "Description", labelStyle: TextStyle(color: Colors.white54))
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: widget.onClose, child: const Text("Cancel")),
                  ElevatedButton(
                    onPressed: () {
                      context.read<RoomBloc>().add(UpdateRoomInfoEvent(roomId: widget.room.id, title: _titleCtrl.text, description: _descCtrl.text));
                      // FIXED: Use callback, NOT Navigator.pop
                      widget.onClose();
                    },
                    child: const Text("Save"),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

// --- 3. Report Dialog (Stack Version) ---
class ReportDialogStack extends StatefulWidget {
  final String roomId;
  final VoidCallback onClose;
  const ReportDialogStack({super.key, required this.roomId, required this.onClose});

  @override
  State<ReportDialogStack> createState() => _ReportDialogStackState();
}

class _ReportDialogStackState extends State<ReportDialogStack> {
  final TextEditingController _reasonCtrl = TextEditingController();
  String _selectedReason = "Spam"; // Default value
  final List<String> _reasons = ["Spam", "Abusive Language", "Inappropriate", "Other"];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(12),
        elevation: 10,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          padding: const EdgeInsets.all(20),
          // Wrap in SingleChildScrollView to prevent overflow with the list
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Report Room", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                const Text("Reason:", style: TextStyle(color: Colors.white70, fontSize: 14)),
                
                // --- FIX: Replace DropdownButton with RadioListTiles ---
                // DropdownButton crashes in Overlays because it needs a Navigator.
                // Radio buttons work perfectly fine here.
                ..._reasons.map((r) => RadioListTile<String>(
                  title: Text(r, style: const TextStyle(color: Colors.white, fontSize: 14)),
                  value: r,
                  groupValue: _selectedReason,
                  activeColor: Colors.redAccent,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  onChanged: (val) => setState(() => _selectedReason = val!),
                )),
                // -----------------------------------------------------

                const SizedBox(height: 10),
                TextField(
                  controller: _reasonCtrl, 
                  style: const TextStyle(color: Colors.white), 
                  decoration: const InputDecoration(
                    hintText: "Description (Optional)", 
                    hintStyle: TextStyle(color: Colors.white54),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  )
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: widget.onClose, child: const Text("Cancel")),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                      onPressed: () {
                        final reporterId = FirebaseAuth.instance.currentUser?.uid ?? "anon";
                        context.read<RoomBloc>().add(ReportRoomEvent(
                          roomId: widget.roomId, 
                          reporterId: reporterId, 
                          reason: _selectedReason, 
                          description: _reasonCtrl.text
                        ));
                        widget.onClose(); // Call callback, NOT Navigator.pop
                      },
                      child: const Text("Report"),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}