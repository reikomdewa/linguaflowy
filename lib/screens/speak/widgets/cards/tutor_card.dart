import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for input formatters
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:livekit_client/livekit_client.dart';

// 1. BLOC & STATE IMPORTS
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_state.dart';
import 'package:linguaflow/blocs/speak/tutor/tutor_bloc.dart';
import 'package:linguaflow/blocs/speak/tutor/tutor_event.dart';
import 'package:linguaflow/blocs/speak/room/room_bloc.dart';
import 'package:linguaflow/blocs/speak/room/room_event.dart';

// 2. MODELS & SERVICES
import 'package:linguaflow/models/speak/room_member.dart';
import 'package:linguaflow/models/speak/speak_models.dart';
import 'package:linguaflow/screens/speak/widgets/active_room_screen.dart';
import 'package:linguaflow/services/speak/speak_service.dart';

class TutorCard extends StatelessWidget {
  final Tutor tutor;

  const TutorCard({super.key, required this.tutor});

  // ==========================================
  // 1. OPTIONS MENU
  // ==========================================
  void _showOptionsMenu(BuildContext context, bool isMe) {
    final theme = Theme.of(context);
    final tutorBloc = context.read<TutorBloc>();

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.favorite_rounded, color: Colors.red),
              title: const Text("Add to Favorites"),
              onTap: () {
                tutorBloc.add(ToggleFavoriteTutor(tutor.id));
                Navigator.pop(ctx);
              },
            ),
            if (isMe) ...[
              const Divider(),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.red,
                ),
                title: const Text(
                  "Delete Tutor Profile",
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showDeleteConfirmation(context, tutorBloc);
                },
              ),
            ],
            ListTile(
              leading: const Icon(Icons.report_gmailerrorred_rounded),
              title: const Text("Report Tutor"),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, TutorBloc bloc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Profile?"),
        content: const Text(
          "Are you sure you want to remove your tutor profile?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              bloc.add(DeleteTutorProfileEvent(tutor.id));
              Navigator.pop(ctx);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 2. ENTRY POINT: HANDLE JOIN LOGIC
  // ==========================================
  Future<void> _handleJoinPress(BuildContext context) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final bool isHost = currentUser.uid == tutor.userId;

    // A. HOST: Setup Session immediately
    if (isHost) {
      _showHostSetupDialog(context);
      return;
    }

    // B. STUDENT: Check Status (Ghost Room Check)
    // Show a loading indicator while we check Firestore
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final roomSnapshot = await FirebaseFirestore.instance
          .collection('rooms')
          .doc(tutor.id)
          .get();

      // Close the loading dialog
      if (context.mounted) Navigator.pop(context);

      bool isLive = roomSnapshot.exists;
      String? roomPassword;

      if (isLive) {
        final data = roomSnapshot.data();
        final members = data?['members'] as List? ?? [];
        roomPassword = data?['password'] as String?;

        // --- GHOST ROOM CHECK ---
        // 1. If members list is empty, room is dead.
        if (members.isEmpty) {
          isLive = false;
        } else {
          // 2. If the HOST is not in the members list, the room is considered dead.
          // We assume the Host's UID is the same as the Tutor ID (tutor.userId)
          final isHostPresent = members.any((m) {
            if (m is Map) return m['uid'] == tutor.userId;
            return false;
          });
          
          if (!isHostPresent) isLive = false;
        }
      }

      if (!context.mounted) return;

      if (isLive) {
        // Tutor is Live -> Check Password
        if (roomPassword != null && roomPassword.isNotEmpty) {
          _showStudentPasswordDialog(context, roomPassword);
        } else {
          _joinTutorSession(context);
        }
      } else {
        // Tutor is Offline -> Show Schedule
        _showScheduleDialog(context);
      }

    } catch (e) {
      // If error occurs (e.g. network), close loading and default to Offline Sheet
      if (context.mounted) {
        Navigator.pop(context); // Ensure loading is closed
        _showScheduleDialog(context); // Fallback to schedule
      }
      debugPrint("Error checking room status: $e");
    }
  }

  // ==========================================
  // 3. DIALOGS
  // ==========================================

  void _showHostSetupDialog(BuildContext context) {
    final TextEditingController passController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Start Session"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Set a password to keep your class private, or leave empty for a public class.",
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: InputDecoration(
                labelText: "Room Password (Optional)",
                hintText: "e.g. 1234",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              final pass = passController.text.trim();
              Navigator.pop(ctx);
              _joinTutorSession(
                context,
                sessionPassword: pass.isEmpty ? null : pass,
              );
            },
            child: const Text("Start Live"),
          ),
        ],
      ),
    );
  }

  void _showStudentPasswordDialog(
    BuildContext context,
    String correctPassword,
  ) {
    final TextEditingController passController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Private Class"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("This class is password protected."),
            const SizedBox(height: 16),
            TextField(
              controller: passController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(
                hintText: "Enter 4-digit code",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              if (passController.text.trim() == correctPassword) {
                Navigator.pop(ctx);
                _joinTutorSession(context); // Success
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Incorrect password"),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text("Join"),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 4. JOIN SESSION LOGIC
  // ==========================================
  Future<void> _joinTutorSession(
    BuildContext context, {
    String? sessionPassword,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception("User not logged in");

      final bool isHost = currentUser.uid == tutor.userId;

      final tutorRoomWrapper = ChatRoom(
        id: tutor.id,
        hostId: tutor.userId,
        title: "${tutor.name}'s Class",
        description: tutor.description,
        language: tutor.language,
        level: tutor.level,
        memberCount: 1,
        maxMembers: 10,
        isPaid: true,
        password: sessionPassword,
        isPrivate: sessionPassword != null && sessionPassword.isNotEmpty,
        hostName: tutor.name,
        hostAvatarUrl: tutor.imageUrl,
        createdAt: DateTime.now(),
        members: [
          RoomMember(
            uid: tutor.userId,
            displayName: tutor.name,
            avatarUrl: tutor.imageUrl,
            joinedAt: DateTime.now(),
            isHost: true,
          ),
        ],
        tags: tutor.specialties,
        roomType: 'tutor_session',
      );

      final Future<String> tokenFuture = SpeakService().getLiveKitToken(
        tutorRoomWrapper.id,
        currentUser.displayName ?? "Student",
      );

      // Handle Firestore (Non-blocking for students)
      if (isHost) {
        await FirebaseFirestore.instance
            .collection('rooms')
            .doc(tutorRoomWrapper.id)
            .set(tutorRoomWrapper.toMap(), SetOptions(merge: true));
      } else {
        final myMember = RoomMember(
          uid: currentUser.uid,
          displayName: currentUser.displayName,
          avatarUrl: currentUser.photoURL,
          joinedAt: DateTime.now(),
        );

        FirebaseFirestore.instance
            .collection('rooms')
            .doc(tutorRoomWrapper.id)
            .update({
              'members': FieldValue.arrayUnion([myMember.toMap()]),
              'memberCount': FieldValue.increment(1),
            })
            .catchError((e) {
              debugPrint("Background Firestore update failed: $e");
            });
      }

      final String token = await tokenFuture;

      final livekitRoom = Room();
      await livekitRoom.connect(
        'wss://linguaflow-7eemmnrq.livekit.cloud',
        token,
      );

      if (context.mounted) {
        context.read<RoomBloc>().add(RoomJoined(livekitRoom));
        Navigator.pop(context);

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ActiveRoomScreen(
              roomData: tutorRoomWrapper,
              livekitRoom: livekitRoom,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("❌ JOIN ERROR: $e");
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error joining class: $e")));
      }
    }
  }

  // ==========================================
  // 5. UI BUILD
  // ==========================================
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: theme.cardColor,
      child: InkWell(
        onTap: () => _handleJoinPress(context),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAvatar(theme),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tutor.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              "${tutor.language} • ${tutor.level}",
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 16,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              tutor.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              " (${tutor.reviews})",
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.hintColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    color: theme.hintColor,
                    onPressed: () {
                      final isMe =
                          FirebaseAuth.instance.currentUser?.uid ==
                          tutor.userId;
                      _showOptionsMenu(context, isMe);
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                tutor.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 12),
              if (tutor.specialties.isNotEmpty) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: tutor.specialties.take(3).map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "#$tag",
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],
              Divider(height: 1, color: theme.dividerColor),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "\$${tutor.pricePerHour.toStringAsFixed(2)}",
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.primaryColor,
                        ),
                      ),
                      Text(
                        "/ 50 min",
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.hintColor,
                        ),
                      ),
                    ],
                  ),
                  _buildActionButtons(context, theme),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(ThemeData theme) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: theme.dividerColor, width: 1),
          ),
          child: CircleAvatar(
            radius: 32,
            backgroundImage: NetworkImage(tutor.imageUrl),
            backgroundColor: theme.canvasColor,
          ),
        ),
        if (tutor.isOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                border: Border.all(color: theme.cardColor, width: 2),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, ThemeData theme) {
    return ElevatedButton.icon(
      onPressed: () => _handleJoinPress(context),
      icon: const Icon(Icons.video_call_rounded, size: 20),
      label: const Text("Join Class"),
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    );
  }

  // ==========================================
  // 6. SCHEDULE DIALOG (Offline View)
  // ==========================================
  void _showScheduleDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final theme = Theme.of(context);
        
        // Ensure we filter out days off or days with no slots
        final activeSchedule = tutor.availability.where((day) => !day.isDayOff && day.slots.isNotEmpty).toList();

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundImage: NetworkImage(tutor.imageUrl),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${tutor.name} is offline",
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "Join when the lesson starts.",
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Title
                Text(
                  "Weekly Schedule",
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.primaryColor,
                  ),
                ),
                const SizedBox(height: 12),

                // Schedule List
                if (activeSchedule.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      "No scheduled hours. Contact tutor directly.",
                      style: TextStyle(color: theme.hintColor),
                    ),
                  )
                else
                  Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.4
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        children: activeSchedule.map((day) {
                          // Format times: e.g. "09:00-12:00, 14:00-18:00"
                          final timesText = day.slots
                              .map((s) => "${s.formattedStart}-${s.formattedEnd}")
                              .join(", ");

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.scaffoldBackgroundColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  day.dayName,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                Flexible(
                                  child: Text(
                                    timesText,
                                    textAlign: TextAlign.right,
                                    style: TextStyle(color: theme.primaryColor),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Close"),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}