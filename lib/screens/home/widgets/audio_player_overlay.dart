import 'dart:async'; // 1. Needed for Timer
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart'; // 2. Needed for Bloc
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart'; // 3. Import AuthBloc
import 'package:linguaflow/blocs/auth/auth_event.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/utils/logger.dart';

// --- MANAGER (SINGLETON) ---
class AudioGlobalManager extends ChangeNotifier {
  static final AudioGlobalManager _instance = AudioGlobalManager._internal();
  factory AudioGlobalManager() => _instance;
  AudioGlobalManager._internal();

  final AudioPlayer _player = AudioPlayer();

  LessonModel? currentLesson;
  bool isExpanded = false;
  bool isPlaying = false;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;

  AudioPlayer get player => _player;

  void playLesson(LessonModel lesson) async {
    // 1. If clicking the same lesson that is already loaded, just expand the UI
    if (currentLesson?.id == lesson.id) {
      isExpanded = true;
      notifyListeners();
      return;
    }

    // 2. Update State for new lesson
    currentLesson = lesson;
    isExpanded = true;
    notifyListeners();

    // 3. Setup Listeners (Updates UI slider/buttons)
    _player.playerStateStream.listen((state) {
      isPlaying = state.playing;
      notifyListeners();
    });
    _player.positionStream.listen((pos) {
      position = pos;
      notifyListeners();
    });
    _player.durationStream.listen((dur) {
      duration = dur ?? Duration.zero;
      notifyListeners();
    });

    // 4. Load Audio with System Notification Data
    try {
      if (lesson.videoUrl != null && lesson.videoUrl!.isNotEmpty) {
        // Create the Metadata for the Notification Center
        final mediaItem = MediaItem(
          id: lesson.id,
          album: "LinguaFlow Audio", // Or use lesson.genre
          title: lesson.title,
          artist: lesson.difficulty.toUpperCase(), // Shows as subtitle
          artUri: lesson.imageUrl != null ? Uri.parse(lesson.imageUrl!) : null,
        );

        // Create the AudioSource with the Metadata tag
        final audioSource = AudioSource.uri(
          Uri.parse(lesson.videoUrl!),
          tag: mediaItem, // <--- This enables the notification
        );

        await _player.setAudioSource(audioSource);
        _player.play();
      } else {
        printLog("AUDIO_MANAGER: Error - URL is null or empty");
      }
    } catch (e) {
      printLog("AUDIO_MANAGER: Error setting audio source: $e");
    }
  }

  void togglePlayPause() {
    if (isPlaying) {
      _player.pause();
    } else {
      _player.play();
    }
  }

  void seek(Duration pos) {
    _player.seek(pos);
  }

  void collapse() {
    isExpanded = false;
    notifyListeners();
  }

  void expand() {
    isExpanded = true;
    notifyListeners();
  }

  void stopAndClose() {
    _player.stop();
    currentLesson = null;
    isExpanded = false;
    notifyListeners();
  }
}

// --- UI OVERLAY (UPDATED FOR TRACKING) ---
class AudioPlayerOverlay extends StatefulWidget {
  const AudioPlayerOverlay({super.key});

  @override
  State<AudioPlayerOverlay> createState() => _AudioPlayerOverlayState();
}

class _AudioPlayerOverlayState extends State<AudioPlayerOverlay> {
  // Tracking Variables
  Timer? _trackingTimer;
  int _sessionSeconds = 0;
  bool _wasPlaying = false;

  @override
  void initState() {
    super.initState();
    // Listen to the manager to handle tracking logic separate from UI rebuilding
    AudioGlobalManager().addListener(_onManagerChanged);
  }

  @override
  void dispose() {
    AudioGlobalManager().removeListener(_onManagerChanged);
    _stopTimer();
    super.dispose();
  }

  void _onManagerChanged() {
    final manager = AudioGlobalManager();

    // 1. Handle Timer Start/Stop based on Playing State
    if (manager.isPlaying && !_wasPlaying) {
      _startTimer();
    } else if (!manager.isPlaying && _wasPlaying) {
      _stopTimer();
    }

    // 2. Handle Closing/Stopping -> Flush Data
    // If currentLesson becomes null, the player was closed.
    if (manager.currentLesson == null && _sessionSeconds > 0) {
      _flushDataToBloc();
    }

    _wasPlaying = manager.isPlaying;
  }

  void _startTimer() {
    _trackingTimer?.cancel();
    _trackingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _sessionSeconds++;
    });
  }

  void _stopTimer() {
    _trackingTimer?.cancel();
  }

  void _flushDataToBloc() {
    _stopTimer(); // Ensure stopped

    // Only update if user listened for more than 30 seconds
    if (_sessionSeconds > 30 && mounted) {
      final int minutesToAdd = (_sessionSeconds / 60).ceil();

      // Dispatch Event to AuthBloc
      context.read<AuthBloc>().add(AuthUpdateListeningTime(minutesToAdd));

      printLog("🎧 TRACKING: Added $minutesToAdd minutes of listening time.");
    }

    // Reset counter
    _sessionSeconds = 0;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AudioGlobalManager(),
      builder: (context, child) {
        final manager = AudioGlobalManager();
        if (manager.currentLesson == null) return const SizedBox.shrink();

        return Stack(
          children: [
            // 1. DIMMED BACKGROUND
            IgnorePointer(
              ignoring: !manager.isExpanded,
              child: GestureDetector(
                onTap: manager.collapse,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  color: manager.isExpanded
                      ? Colors.black.withValues(alpha: 0.7)
                      : Colors.transparent,
                ),
              ),
            ),

            // 2. FLOATING PLAYER CARD
            Align(
              alignment: Alignment.bottomCenter,
              child: _MorphingPlayerCard(manager: manager),
            ),
          ],
        );
      },
    );
  }
}

class _MorphingPlayerCard extends StatelessWidget {
  final AudioGlobalManager manager;

  const _MorphingPlayerCard({required this.manager});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // --- DIMENSIONS & POSITIONING ---
    final double targetHeight = manager.isExpanded ? screenHeight * 0.55 : 70;

    // Center vertical position logic
    final double targetBottomMargin = manager.isExpanded
        ? (screenHeight - targetHeight) / 2 - 100
        : 90; // Above FABs

    final double sideMargin = 16.0;
    final double borderRadius = 24.0;

    // --- THEME COLORS ---
    final List<Color> expandedGradient = isDark
        ? [const Color(0xFF2C2C2C), const Color(0xFF000000)]
        : [const Color(0xFFFFFFFF), const Color(0xFFF5F5F5)];

    final Color baseColor = isDark ? const Color(0xFF2C2C2C) : Colors.white;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      height: targetHeight,
      margin: EdgeInsets.only(
        left: sideMargin,
        right: sideMargin,
        bottom: targetBottomMargin,
      ),
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2), // Softer shadow
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
        gradient: manager.isExpanded
            ? LinearGradient(
                colors: expandedGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: manager.isExpanded ? null : manager.expand,
          onVerticalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            if (manager.isExpanded) {
              if (velocity > 300) manager.collapse();
            } else {
              if (velocity < -300) {
                manager.expand();
              } else if (velocity > 300) {
                manager.stopAndClose();
              }
            }
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: SizedBox(
                height: targetHeight,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) =>
                      FadeTransition(opacity: animation, child: child),
                  child: manager.isExpanded
                      ? _buildExpandedContent(context, isDark)
                      : _buildMiniContent(context, isDark),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- MINI CONTENT ---
  Widget _buildMiniContent(BuildContext context, bool isDark) {
    final lesson = manager.currentLesson!;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Container(
      key: const ValueKey('mini'),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.center,
      child: Row(
        children: [
          // Thumbnail
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              image: lesson.imageUrl != null
                  ? DecorationImage(
                      image: NetworkImage(lesson.imageUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
              color: Colors.purple.shade100,
            ),
            child: lesson.imageUrl == null
                ? const Icon(Icons.music_note, color: Colors.purple)
                : null,
          ),
          const SizedBox(width: 12),

          // Text
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lesson.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: textColor,
                  ),
                ),
                Text(
                  "Swipe up to expand",
                  style: TextStyle(fontSize: 11, color: subTextColor),
                ),
              ],
            ),
          ),

          // Controls
          IconButton(
            icon: Icon(
              manager.isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
            ),
            color: Colors.purple,
            iconSize: 30,
            onPressed: manager.togglePlayPause,
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded),
            color: Colors.grey,
            iconSize: 22,
            onPressed: manager.stopAndClose,
          ),
        ],
      ),
    );
  }

  // --- EXPANDED CONTENT ---
  Widget _buildExpandedContent(BuildContext context, bool isDark) {
    final lesson = manager.currentLesson!;

    // Theme-aware colors
    final mainTextColor = isDark ? Colors.white : Colors.black;
    final secondaryTextColor = isDark ? Colors.white70 : Colors.black54;
    final iconColor = isDark ? Colors.white70 : Colors.black54;

    final playBtnBg = isDark ? Colors.white : Colors.black;
    final playBtnIcon = isDark ? Colors.black : Colors.white;

    return Column(
      key: const ValueKey('expanded'),
      children: [
        // 1. Header (Collapse Arrow)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: secondaryTextColor,
                  size: 28,
                ),
                onPressed: manager.collapse,
              ),
            ],
          ),
        ),

        // 2. Main Content
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Image
                Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 15,
                      ),
                    ],
                    image: lesson.imageUrl != null
                        ? DecorationImage(
                            image: NetworkImage(lesson.imageUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                    color: Colors.grey.shade200,
                  ),
                ),

                // Title
                Text(
                  lesson.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: mainTextColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                // Slider & Time
                Column(
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4,
                        thumbColor: mainTextColor,
                        activeTrackColor: mainTextColor,
                        inactiveTrackColor: isDark
                            ? Colors.white24
                            : Colors.black12,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6,
                        ),
                        overlayShape: SliderComponentShape.noOverlay,
                      ),
                      child: Slider(
                        value: manager.position.inSeconds.toDouble(),
                        min: 0,
                        max: manager.duration.inSeconds.toDouble() > 0
                            ? manager.duration.inSeconds.toDouble()
                            : 1.0,
                        onChanged: (val) =>
                            manager.seek(Duration(seconds: val.toInt())),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(manager.position),
                          style: TextStyle(
                            color: secondaryTextColor,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          _formatDuration(manager.duration),
                          style: TextStyle(
                            color: secondaryTextColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.replay_10_rounded,
                        color: iconColor,
                        size: 30,
                      ),
                      onPressed: () => manager.seek(
                        manager.position - const Duration(seconds: 10),
                      ),
                    ),
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: playBtnBg,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: Icon(
                          manager.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: playBtnIcon,
                          size: 36,
                        ),
                        onPressed: manager.togglePlayPause,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.forward_30_rounded,
                        color: iconColor,
                        size: 30,
                      ),
                      onPressed: () => manager.seek(
                        manager.position + const Duration(seconds: 30),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }
}
