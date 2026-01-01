import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/screens/speak/active_screen/managers/room_global_manager.dart';
import 'package:livekit_client/livekit_client.dart';

// BLOCS
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_state.dart';
// Ensure this imports AuthFollowUser/AuthUnfollowUser
import 'package:linguaflow/blocs/auth/auth_event.dart';
import 'package:linguaflow/blocs/speak/tutor/tutor_bloc.dart';
import 'package:linguaflow/blocs/speak/tutor/tutor_event.dart';
import 'package:linguaflow/blocs/speak/room/room_bloc.dart';
import 'package:linguaflow/blocs/speak/room/room_event.dart';

// MODELS & SERVICES
import 'package:linguaflow/models/speak/room_member.dart';
import 'package:linguaflow/models/speak/speak_models.dart';
import 'package:linguaflow/services/speak/speak_service.dart';
import 'package:linguaflow/services/speak/private_chat_service.dart';
import 'package:linguaflow/screens/inbox/private_chat_screen.dart';

class TutorCard extends StatelessWidget {
  final Tutor tutor;

  const TutorCard({super.key, required this.tutor});

  // ==========================================
  // 1. OPTIONS MENU
  // ==========================================
  void _showOptionsMenu(BuildContext context, bool isMe) {
    final theme = Theme.of(context);
    final tutorBloc = context.read<TutorBloc>();

    // Check auth state for following status
    final authState = context.read<AuthBloc>().state;
    bool isFollowing = false;
    if (authState is AuthAuthenticated) {
      isFollowing = authState.user.following.contains(tutor.userId);
    }

    // Check if already favorite (Mock for now)
    bool isFavorite = false;

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

            if (isMe) ...[
              // A. OWNER OPTIONS
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.red,
                ),
                title: const Text(
                  "Delete Tutor Profile",
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showDeleteConfirmation(context, tutorBloc);
                },
              ),
            ] else ...[
              // B. VISITOR OPTIONS

              // 1. Follow Option (Quick Access)
              ListTile(
                leading: Icon(
                  isFollowing
                      ? Icons.person_remove_rounded
                      : Icons.person_add_rounded,
                  color: theme.primaryColor,
                ),
                title: Text(isFollowing ? "Unfollow Tutor" : "Follow Tutor"),
                onTap: () {
                  if (isFollowing) {
                    context.read<AuthBloc>().add(
                      AuthUnfollowUser(tutor.userId),
                    );
                  } else {
                    context.read<AuthBloc>().add(AuthFollowUser(tutor.userId));
                  }
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isFollowing ? "Unfollowed" : "Following ${tutor.name}",
                      ),
                    ),
                  );
                },
              ),

              // 2. Favorite Option
              ListTile(
                leading: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: Colors.red,
                ),
                title: Text(
                  isFavorite ? "Remove from Favorites" : "Add to Favorites",
                ),
                onTap: () {
                  tutorBloc.add(ToggleFavoriteTutor(tutor.id));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isFavorite
                            ? "Removed from favorites"
                            : "Added to favorites",
                      ),
                    ),
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.report_gmailerrorred_rounded),
                title: const Text("Report Tutor"),
                onTap: () {
                  Navigator.pop(ctx);
                  _showReportDialog(context, tutorBloc);
                },
              ),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ... (Delete and Report Dialogs remain unchanged) ...
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

  void _showReportDialog(BuildContext context, TutorBloc bloc) {
    final TextEditingController reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Report Tutor"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Please describe why you are reporting this profile."),
            const SizedBox(height: 10),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: "Reason...",
                border: OutlineInputBorder(),
              ),
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
              if (reasonController.text.trim().isNotEmpty) {
                bloc.add(
                  ReportTutorEvent(
                    tutorId: tutor.id,
                    reason: reasonController.text.trim(),
                  ),
                );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Report submitted.")),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Report", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 2. MESSAGE LOGIC
  // ==========================================
  Future<void> _handleMessagePress(BuildContext context) async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please log in.")));
      return;
    }
    final myUser = authState.user;
    if (myUser.id == tutor.userId) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Cannot message yourself.")));
      return;
    }

    try {
      final chatId = await PrivateChatService().startChat(
        currentUserId: myUser.id,
        otherUserId: tutor.userId,
        currentUserName: myUser.displayName,
        otherUserName: tutor.name,
        currentUserPhoto: myUser.photoUrl,
        otherUserPhoto: tutor.imageUrl,
      );
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PrivateChatScreen(
              chatId: chatId,
              otherUserName: tutor.name,
              otherUserPhoto: tutor.imageUrl,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error starting chat: $e");
    }
  }

  // ==========================================
  // 3. JOIN LOGIC (Unchanged)
  // ==========================================
  // ... (Keep _handleJoinPress, _showHostSetupDialog, _showStudentPasswordDialog, _joinTutorSession exactly as they were) ...

  // Just for brevity in this response, I'm hiding the unchanged connection logic blocks.
  // Assume _handleJoinPress etc. are here exactly as you provided.
  Future<void> _handleJoinPress(BuildContext context) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    final bool isHost = currentUser.uid == tutor.userId;
    if (isHost) {
      _showHostSetupDialog(context);
      return;
    }

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
      if (context.mounted) Navigator.pop(context);
      bool isLive = roomSnapshot.exists;
      String? roomPassword;
      if (isLive) {
        final data = roomSnapshot.data();
        final members = data?['members'] as List? ?? [];
        roomPassword = data?['password'] as String?;
        if (members.isEmpty)
          isLive = false;
        else {
          final isHostPresent = members.any(
            (m) => (m is Map) ? m['uid'] == tutor.userId : false,
          );
          if (!isHostPresent) isLive = false;
        }
      }
      if (!context.mounted) return;
      if (isLive) {
        if (roomPassword != null && roomPassword.isNotEmpty)
          _showStudentPasswordDialog(context, roomPassword);
        else
          _joinTutorSession(context);
      } else {
        _showScheduleDialog(context);
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        _showScheduleDialog(context);
      }
    }
  }

  void _showHostSetupDialog(BuildContext context) {
    final TextEditingController passController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Start Session"),
        content: TextField(
          controller: passController,
          keyboardType: TextInputType.number,
          maxLength: 4,
          decoration: const InputDecoration(
            labelText: "Room Password (Optional)",
            hintText: "e.g. 1234",
            border: OutlineInputBorder(),
          ),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
        content: TextField(
          controller: passController,
          keyboardType: TextInputType.number,
          maxLength: 4,
          obscureText: true,
          decoration: const InputDecoration(
            hintText: "Enter 4-digit code",
            border: OutlineInputBorder(),
          ),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                _joinTutorSession(context);
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

Future<void> _joinTutorSession(
    BuildContext context, {
    String? sessionPassword,
  }) async {
    // 1. Show Loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception("User not logged in");

      final firestore = FirebaseFirestore.instance;
      final roomBloc = context.read<RoomBloc>();

      // ============================================================
      // STEP A: CLEANUP - Remove user from ANY other rooms first
      // ============================================================
      
      // 1. Identify rooms the user is currently in (excluding the one they are trying to join)
      final roomsToLeave = roomBloc.state.allRooms.where((r) {
        final isDifferentRoom = r.id != tutor.id;
        final isInRoom = r.members.any((m) => m.uid == currentUser.uid);
        return isDifferentRoom && isInRoom;
      }).toList();

      // 2. Remove user from those rooms in Firestore
      for (final oldRoom in roomsToLeave) {
        try {
          final oldRoomRef = firestore.collection('rooms').doc(oldRoom.id);
          
          await firestore.runTransaction((transaction) async {
            final snapshot = await transaction.get(oldRoomRef);
            if (!snapshot.exists) return;

            final currentData = snapshot.data()!;
            final rawList = currentData['members'] as List<dynamic>? ?? [];

            // Parse members safely
            final members = rawList.map((m) {
              if (m is Map<String, dynamic>) return RoomMember.fromMap(m);
              if (m is Map) return RoomMember.fromMap(Map<String, dynamic>.from(m));
              return null;
            }).where((m) => m != null).cast<RoomMember>().toList();

            // Remove the current user
            final initialCount = members.length;
            members.removeWhere((m) => m.uid == currentUser.uid);

            // Only update if changes were made
            if (members.length < initialCount) {
              transaction.update(oldRoomRef, {
                'members': members.map((m) => m.toMap()).toList(),
                'memberCount': members.length,
                'lastUpdatedAt': FieldValue.serverTimestamp(),
              });
            }
          });
          debugPrint("🧹 Automatically removed user from old room: ${oldRoom.title}");
        } catch (e) {
          debugPrint("⚠️ Failed to leave old room ${oldRoom.id}: $e");
        }
      }

      // ============================================================
      // STEP B: JOIN NEW SESSION
      // ============================================================

      final bool isHost = currentUser.uid == tutor.userId;

      // 1. Create the Room Wrapper
      final tutorRoomWrapper = ChatRoom(
        id: tutor.id,
        hostId: tutor.userId,
        title: "${tutor.name}'s Class",
        description: tutor.description,
        language: tutor.language,
        level: tutor.level,
        memberCount: 1, // Will be updated via Firestore logic below
        maxMembers: 10,
        isPaid: true,
        password: sessionPassword,
        isPrivate: sessionPassword != null && sessionPassword.isNotEmpty,
        hostName: tutor.name,
        hostAvatarUrl: tutor.imageUrl,
        createdAt: DateTime.now(),
        members: [
          // We initialize with just the Host, logic below handles appending student
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

      // 2. Get LiveKit Token
      final token = await SpeakService().getLiveKitToken(
        tutorRoomWrapper.id,
        currentUser.displayName ?? "Student",
      );

      // 3. Sync with Firestore
      if (isHost) {
        // If Host, ensure room exists/updates
        await firestore
            .collection('rooms')
            .doc(tutorRoomWrapper.id)
            .set(tutorRoomWrapper.toMap(), SetOptions(merge: true));
      } else {
        // If Student, Add to list safely (Transaction ensures we don't overwrite others)
        final roomRef = firestore.collection('rooms').doc(tutorRoomWrapper.id);
        
        await firestore.runTransaction((transaction) async {
          final snapshot = await transaction.get(roomRef);
          List<RoomMember> currentMembers = [];
          
          if (snapshot.exists) {
            final data = snapshot.data()!;
             final rawList = data['members'] as List<dynamic>? ?? [];
             currentMembers = rawList.map((m) {
                if (m is Map<String, dynamic>) return RoomMember.fromMap(m);
                if (m is Map) return RoomMember.fromMap(Map<String, dynamic>.from(m));
                return null;
             }).where((m) => m != null).cast<RoomMember>().toList();
          } else {
            // If room doesn't exist yet (Host hasn't joined), create basic structure
            currentMembers = List.from(tutorRoomWrapper.members);
          }

          // Add student if not present
          if (!currentMembers.any((m) => m.uid == currentUser.uid)) {
            final myMember = RoomMember(
              uid: currentUser.uid,
              displayName: currentUser.displayName,
              avatarUrl: currentUser.photoURL,
              joinedAt: DateTime.now(),
              isHost: false,
            );
            currentMembers.add(myMember);
            
            transaction.set(roomRef, {
              ...tutorRoomWrapper.toMap(), // Ensures base fields exist
              'members': currentMembers.map((m) => m.toMap()).toList(),
              'memberCount': currentMembers.length,
            }, SetOptions(merge: true));
          }
        });
      }

      // 4. Connect to LiveKit
      final livekitRoom = Room();
      await livekitRoom.connect(
        'wss://linguaflow-7eemmnrq.livekit.cloud',
        token,
      );

      if (context.mounted) {
        // --- 5. ACTIVATE GLOBAL OVERLAY ---
        RoomGlobalManager().joinRoom(livekitRoom, tutorRoomWrapper);

        // Update Bloc state to reflect "Active" status in UI
        context.read<RoomBloc>().add(RoomJoined(livekitRoom));

        // 6. Hide Loading Dialog
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error joining class: $e")),
        );
      }
    }
  }

  // ==========================================
  // 4. UI BUILD
  // ==========================================
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = context.read<AuthBloc>().state;
    bool isMe = false;
    if (authState is AuthAuthenticated) {
      isMe = authState.user.id == tutor.userId;
    }

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
                        Text(
                          "${tutor.language} • ${tutor.level}",
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
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
                    onPressed: () => _showOptionsMenu(context, isMe),
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
                  children: tutor.specialties
                      .take(3)
                      .map(
                        (tag) => Container(
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
                        ),
                      )
                      .toList(),
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
                  _buildActionButtons(context, theme, isMe),
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

  Widget _buildActionButtons(BuildContext context, ThemeData theme, bool isMe) {
    return ElevatedButton.icon(
      onPressed: () => _handleJoinPress(context),
      icon: const Icon(Icons.video_call_rounded, size: 20),
      label: Text(isMe ? "Start Class" : "Join Class"),
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.primaryColor,
        foregroundColor: theme.canvasColor,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  // --- NEW: Helper Widget for Follow/Unfollow Button ---
  Widget _buildFollowButton(BuildContext context, bool isMe, ThemeData theme) {
    if (isMe) return const SizedBox.shrink();

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        bool isFollowing = false;
        if (state is AuthAuthenticated) {
          isFollowing = state.user.following.contains(tutor.userId);
        }

        return GestureDetector(
          onTap: () {
            if (isFollowing) {
              context.read<AuthBloc>().add(AuthUnfollowUser(tutor.userId));
            } else {
              context.read<AuthBloc>().add(AuthFollowUser(tutor.userId));
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              // If Following: Outline style. If Not: Filled style.
              color: isFollowing ? Colors.transparent : theme.primaryColor,
              border: isFollowing
                  ? Border.all(color: theme.dividerColor)
                  : null,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isFollowing ? Icons.check : Icons.person_add_alt_1_rounded,
                  color: isFollowing
                      ? theme.textTheme.bodyMedium?.color
                      : theme.cardColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  isFollowing ? "Following" : "Follow Tutor",
                  style: TextStyle(
                    color: isFollowing
                        ? theme.textTheme.bodyMedium?.color
                        : theme.cardColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showScheduleDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final theme = Theme.of(context);
        final activeSchedule = tutor.availability
            .where((day) => !day.isDayOff && day.slots.isNotEmpty)
            .toList();
        final authState = context.read<AuthBloc>().state;
        bool isMe = false;
        if (authState is AuthAuthenticated)
          isMe = authState.user.id == tutor.userId;

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
                            "Follow to know when the lesson start",
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
                const SizedBox(height: 20),

                // 1. Message Button
                if (!isMe)
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      _handleMessagePress(context);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            color: theme.primaryColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Message Tutor',
                            style: TextStyle(
                              color: theme.primaryColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // 2. NEW: Follow Button (Below Message)
                if (!isMe) ...[
                  const SizedBox(height: 12), // Spacing
                  _buildFollowButton(context, isMe, theme),
                ],

                const SizedBox(height: 24),

                // Schedule List
                Text(
                  "Weekly Schedule",
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.primaryColor,
                  ),
                ),
                const SizedBox(height: 12),
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
                      maxHeight: MediaQuery.of(context).size.height * 0.3,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        children: activeSchedule.map((day) {
                          final timesText = day.slots
                              .map(
                                (s) => "${s.formattedStart}-${s.formattedEnd}",
                              )
                              .join(", ");
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.scaffoldBackgroundColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  day.dayName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
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
              ],
            ),
          ),
        );
      },
    );
  }
}
