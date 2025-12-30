import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:livekit_client/livekit_client.dart';

// --- YOUR SPECIFIC IMPORTS ---
import 'package:linguaflow/blocs/speak/room/room_bloc.dart';
import 'package:linguaflow/blocs/speak/room/room_event.dart';
import 'package:linguaflow/models/speak/chat_room.dart';
import 'package:linguaflow/screens/speak/widgets/active_room_screen.dart';
import 'package:linguaflow/services/speak/speak_service.dart';

class LiveNotificationBanner extends StatefulWidget {
  const LiveNotificationBanner({super.key});

  @override
  State<LiveNotificationBanner> createState() => _LiveNotificationBannerState();
}

class _LiveNotificationBannerState extends State<LiveNotificationBanner>
    with SingleTickerProviderStateMixin {
  
  // --- CONSTANTS ---
  static const Duration kBannerDisplayDuration = Duration(seconds: 10);
  static const Duration kBannerHiddenDuration = Duration(seconds: 30);

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
    // If visible: we wait 10s (Display Duration).
    // If hidden: we wait 30s (Hidden Duration).
    final duration = _isVisible ? kBannerDisplayDuration : kBannerHiddenDuration;

    _cycleTimer = Timer(duration, () {
      if (!mounted) return;

      if (_isVisible) {
        // CASE A: It was visible. Now we HIDE it.
        setState(() {
          _isVisible = false;
          _roomToShow = null;
        });
        // Recursively call to start the 30s wait
        _startDisplayCycle();
      } else {
        // CASE B: It was hidden. Now we try to SHOW it.
        // We pick a room. If found, _pickRandomRoom sets _isVisible = true.
        _pickRandomRoom();
        
        // Only recurse if we actually found a room and became visible.
        // If no room found, we wait and try again later.
        if (_isVisible) {
          _startDisplayCycle();
        } else {
          // No rooms available right now? Check again in 30 seconds.
           _startDisplayCycle();
        }
      }
    });
  }

  void _pickRandomRoom() {
    if (!mounted) return;

    // Check if we have rooms available
    final currentUser = FirebaseAuth.instance.currentUser;
    final validRooms = _currentAvailableRooms
        .where((r) => r.hostId != currentUser?.uid)
        .toList();

    if (validRooms.isNotEmpty) {
      setState(() {
        final randomIndex = _random.nextInt(validRooms.length);
        _roomToShow = validRooms[randomIndex];
        _isVisible = true; // Make visible
      });
    } else {
      // No rooms? Ensure we stay hidden
      if (_isVisible) {
        setState(() {
          _isVisible = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ChatRoom>>(
      stream: SpeakService().getPublicRoomsStream(),
      builder: (context, snapshot) {
        // Update internal list whenever Firebase updates
        if (snapshot.hasData) {
          _currentAvailableRooms = snapshot.data!;

          // FIX: Use addPostFrameCallback to avoid "setState during build" error
          if (_cycleTimer == null && _currentAvailableRooms.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _cycleTimer == null) {
                // Initial start: Pick immediately, then start loop
                _pickRandomRoom(); 
                if (_isVisible) {
                  _startDisplayCycle();
                }
              }
            });
          }
        }

        // AnimatedSize handles the height change (0 -> size) smoothly
        return AnimatedSize(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          child: _isVisible && _roomToShow != null
              ? _buildBanner(context, _roomToShow!)
              : const SizedBox.shrink(),
        );
      },
    );
  }

  Widget _buildBanner(BuildContext context, ChatRoom room) {
    final theme = Theme.of(context);
    // Use secondary (HyperBlue) so it works in Dark & Light mode
    final bannerColor = theme.colorScheme.secondary;

    return Dismissible(
      key: ValueKey(room.id),
      direction: DismissDirection.up,
      onDismissed: (_) {
        setState(() {
          // If user swipes away manually
          _isVisible = false;
          _cycleTimer?.cancel();
          // Reset timer to wait the hidden duration before showing again
          _cycleTimer = Timer(kBannerHiddenDuration, () {
             if (mounted) {
               _pickRandomRoom();
               if (_isVisible) _startDisplayCycle();
             }
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
              // Avatar with "Live" badge
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

              // Text Content
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

              // Arrow Icon
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
    // 1. Show Loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // REPLACE WITH YOUR LIVEKIT URL
      const liveKitUrl = 'wss://linguaflow-7eemmnrq.livekit.cloud';

      final currentUser = FirebaseAuth.instance.currentUser;
      final username = currentUser?.displayName ?? "Guest";

      // 2. Get Token
      final token = await SpeakService().getLiveKitToken(roomData.id, username);

      // 3. Connect
      final room = Room();
      final options = const RoomOptions(adaptiveStream: true, dynacast: true);

      await room.connect(liveKitUrl, token, roomOptions: options);

      // 4. Success
      if (context.mounted) {
        Navigator.pop(context); // Remove Loading

        // Notify RoomBloc (Using the import you provided)
        context.read<RoomBloc>().add(RoomJoined(room));

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ActiveRoomScreen(roomData: roomData, livekitRoom: room),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Remove Loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to join: $e")),
        );
      }
    }
  }
}