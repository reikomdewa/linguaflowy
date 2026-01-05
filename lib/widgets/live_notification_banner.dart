import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:linguaflow/blocs/speak/room/room_bloc.dart';
import 'package:linguaflow/blocs/speak/room/room_event.dart';
import 'package:linguaflow/core/env.dart';
import 'package:linguaflow/screens/speak/active_screen/managers/room_global_manager.dart';
import 'package:linguaflow/screens/speak/utils/remote_config_utils.dart';
import 'package:livekit_client/livekit_client.dart';

// --- BLOC IMPORTS ---
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_state.dart';
// Switched to SpeakBloc to be safe (since you said you haven't separated them yet)
import 'package:linguaflow/blocs/speak/speak_event.dart';

// --- MODEL & SERVICE IMPORTS ---
import 'package:linguaflow/models/user_model.dart';
import 'package:linguaflow/models/speak/chat_room.dart';
import 'package:linguaflow/services/speak/speak_service.dart';

// --- HELPER IMPORT ---
import 'package:linguaflow/utils/language_helper.dart';

class LiveNotificationBanner extends StatefulWidget {
  const LiveNotificationBanner({super.key});

  @override
  State<LiveNotificationBanner> createState() => _LiveNotificationBannerState();
}

class _LiveNotificationBannerState extends State<LiveNotificationBanner>
    with SingleTickerProviderStateMixin {
  // --- CONSTANTS ---
  static const Duration kBannerDisplayDuration = Duration(seconds: 20);
  static const Duration kBannerHiddenDuration = Duration(seconds: 90);

  // State Variables
  List<ChatRoom> _currentAvailableRooms = [];
  ChatRoom? _roomToShow;
  bool _isVisible = false;
  Timer? _cycleTimer;
  final Random _random = Random();

  @override
  void dispose() {
    _cycleTimer?.cancel();
    super.dispose();
  }

  /// The main logic loop
  void _startDisplayCycle() {
    if (!mounted) return;

    // Determine how long to wait based on CURRENT state.
    final duration = _isVisible
        ? kBannerDisplayDuration
        : kBannerHiddenDuration;

    _cycleTimer = Timer(duration, () {
      if (!mounted) return;

      if (_isVisible) {
        // CASE A: Hide
        setState(() {
          _isVisible = false;
          _roomToShow = null;
        });
        _startDisplayCycle();
      } else {
        // CASE B: Try to Show (Smart Pick)
        _attemptToPickAndShow();
      }
    });
  }

  /// Tries to pick a room. If fails, waits and retries (Breaks infinite loop).
  void _attemptToPickAndShow() {
    _pickSmartRoom(); // This updates _isVisible and _roomToShow

    if (_isVisible) {
      // Success! Room found. Schedule hide.
      _startDisplayCycle();
    } else {
      // Failed (No valid rooms). Wait the hidden duration, then try again.
      // THIS WAS MISSING PREVIOUSLY CAUSING THE CRASH
      _cycleTimer = Timer(kBannerHiddenDuration, () {
        if (mounted) _attemptToPickAndShow();
      });
    }
  }

  /// SMART PICK LOGIC
  /// SMART PICK LOGIC
  void _pickSmartRoom() {
    if (!mounted) return;

    // 1. Get Current User from AuthBloc
    final authState = context.read<AuthBloc>().state;
    final UserModel? user = authState.user;

    // 2. Filter valid rooms (exclude own rooms AND inactive rooms)
    final currentFirebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;

    List<ChatRoom> candidates = _currentAvailableRooms.where((r) {
      // Fix: Strictly check if room is active
      if (r.isActive == false) return false;

      // Fix: Don't show the user's own room
      if (currentFirebaseUser != null && r.hostId == currentFirebaseUser.uid) {
        return false;
      }

      return true;
    }).toList();

    // If no candidates remain after filtering, hide the banner
    if (candidates.isEmpty) {
      if (_isVisible) setState(() => _isVisible = false);
      return;
    }

    // 3. Score the rooms
    candidates.sort((a, b) {
      int scoreA = _calculateRoomScore(a, user);
      int scoreB = _calculateRoomScore(b, user);
      return scoreB.compareTo(scoreA);
    });

    // 4. Select the best room
    setState(() {
      int topScore = _calculateRoomScore(candidates.first, user);

      if (topScore > 0) {
        _roomToShow = candidates.first;
      } else {
        // If all scores are 0, pick random so we don't always show the same one
        final randomIndex = _random.nextInt(candidates.length);
        _roomToShow = candidates[randomIndex];
      }

      _isVisible = true;
    });
  }

  int _calculateRoomScore(ChatRoom room, UserModel? user) {
    if (user == null) return 0;

    int score = 0;

    // 1. Language Match
    String targetLangCode = user.currentLanguage;
    String targetLangName = LanguageHelper.getLanguageName(targetLangCode);

    if (room.language.toLowerCase().contains(targetLangName.toLowerCase())) {
      score += 10;
    }

    // 2. Level Match
    String currentLevelFull = user.languageLevels[targetLangCode] ?? '';
    if (currentLevelFull.isNotEmpty) {
      String currentLevelCode = currentLevelFull.split(' ').first;
      if (room.level.contains(currentLevelCode)) {
        score += 5;
      }
    }

    // 3. Friend Match
    if (user.friends.contains(room.hostId)) score += 20;

    return score;
  }

  @override
  Widget build(BuildContext context) {
    // Wrapped in BlocBuilder to react to settings changes
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        return StreamBuilder<List<ChatRoom>>(
          stream: SpeakService().getPublicRoomsStream(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              _currentAvailableRooms = snapshot.data!;

              // Initial Load Logic
              // Only start if timer is null AND we have potential rooms
              if (_cycleTimer == null && _currentAvailableRooms.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _cycleTimer == null) {
                    _attemptToPickAndShow(); // Uses the safe retry logic
                  }
                });
              }
            }

            return AnimatedSize(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
              child: _isVisible && _roomToShow != null
                  ? _buildBanner(context, _roomToShow!)
                  : const SizedBox.shrink(),
            );
          },
        );
      },
    );
  }

  Widget _buildBanner(BuildContext context, ChatRoom room) {
    final theme = Theme.of(context);
    final bannerColor = theme.colorScheme.secondary;

    return Dismissible(
      key: ValueKey(room.id),
      direction: DismissDirection.up,
      onDismissed: (_) {
        setState(() {
          _isVisible = false;
          _cycleTimer?.cancel();
          // Wait before showing again
          _cycleTimer = Timer(kBannerHiddenDuration, () {
            if (mounted) _attemptToPickAndShow();
          });
        });
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [bannerColor, bannerColor.withOpacity(0.85)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: bannerColor.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: InkWell(
          onTap: () => _joinRoom(context, room),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.5),
                        width: 1.5,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      backgroundImage:
                          room.hostAvatarUrl != null &&
                              room.hostAvatarUrl!.isNotEmpty
                          ? NetworkImage(room.hostAvatarUrl!)
                          : null,
                      child:
                          (room.hostAvatarUrl == null ||
                              room.hostAvatarUrl!.isEmpty)
                          ? const Icon(Icons.person, color: Colors.white)
                          : null,
                    ),
                  ),
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF3B30),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: const Text(
                        "LIVE",
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "${room.hostName ?? 'Someone'} is live!",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Speaking: ${room.title}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  FontAwesomeIcons.arrowRight,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _joinRoom(BuildContext context, ChatRoom roomData) async {
    // 1. Show Loading Indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
          final liveKitUrl = await RemoteConfigUtils.getLiveKitUrl(
        forceRefresh: true,
      );

      final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
      final username = currentUser?.displayName ?? "Guest";

      // 2. Get Token
      final token = await SpeakService().getLiveKitToken(roomData.id, username);

      // 3. Connect LiveKit
      final room = Room();
      final options = const RoomOptions(adaptiveStream: true, dynacast: true);

      await room.connect(liveKitUrl, token, roomOptions: options);

      if (context.mounted) {
        // --- 4. ACTIVATE GLOBAL OVERLAY ---
        // Pass the connected room to the manager to show the TikTok-style overlay
        RoomGlobalManager().joinRoom(room, roomData);

        // 5. Update Bloc (Keep state in sync)
        context.read<RoomBloc>().add(RoomJoined(room));

        // 6. Hide Loading Dialog
        Navigator.pop(context);

        // REMOVED: Navigator.push(...)
        // The Overlay now handles the UI.
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Dismiss loading
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to join: $e")));
      }
    }
  }
}
