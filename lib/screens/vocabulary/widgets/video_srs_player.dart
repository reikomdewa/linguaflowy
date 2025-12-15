import 'dart:async';
import 'package:flutter/material.dart';
import 'package:linguaflow/screens/reader/utils/media_lifecycle.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

// Import the MainNavigationScreen to access ActiveTabNotifier
import 'package:linguaflow/screens/main_navigation_screen.dart';

class VideoSRSPlayer extends StatefulWidget {
  final String videoUrl;
  final double startSeconds;
  final double endSeconds;

  const VideoSRSPlayer({
    super.key,
    required this.videoUrl,
    required this.startSeconds,
    required this.endSeconds,
  });

  @override
  State<VideoSRSPlayer> createState() => _VideoSRSPlayerState();
}

class _VideoSRSPlayerState extends State<VideoSRSPlayer> {
  // YouTube State
  YoutubePlayerController? _ytController;
  bool _isYoutube = false;

  // Local Media State
  Player? _localPlayer;
  VideoController? _localVideoController;
  bool _isLocalReady = false;

  bool _isReady = false;

  // CONSTANT: The index of the Vocabulary Tab in MainNavigationScreen
  static const int kVocabularyTabIndex = 2;

  @override
  void initState() {
    super.initState();
  
  }

  // --- AUTO PAUSE LOGIC ---
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final activeTab = ActiveTabNotifier.of(context);

    // If this tab just became active and we haven't initialized yet:
    if (activeTab == kVocabularyTabIndex &&
        !_isReady &&
        _localPlayer == null &&
        _ytController == null) {
      _checkTypeAndInit();
    }
    // If tab is inactive, pause
    else if (activeTab != kVocabularyTabIndex) {
      _pauseVideo();
    }
  }

  void _pauseVideo() {
    if (_isYoutube && _ytController != null) {
      if (_ytController!.value.isPlaying) _ytController!.pause();
    } else if (_localPlayer != null) {
      if (_localPlayer!.state.playing) _localPlayer!.pause();
    }
  }
  // ------------------------

  Future<void> _checkTypeAndInit() async {
    if (widget.videoUrl.toLowerCase().contains('youtube.com') ||
        widget.videoUrl.toLowerCase().contains('youtu.be')) {
      _initYoutube();
    } else {
      _initLocalMedia();
    }
  }

  void _initYoutube() {
    if (!mounted) return;
    setState(() => _isYoutube = true);
    final videoId = YoutubePlayer.convertUrlToId(widget.videoUrl);
    if (videoId != null) {
      _ytController = YoutubePlayerController(
        initialVideoId: videoId,
        flags: YoutubePlayerFlags(
          autoPlay: false, // <--- FIX: Prevent auto-play
          hideControls: false,
          mute: false,
          startAt: widget.startSeconds.toInt(),
        ),
      );
    }
  }

  Future<void> _initLocalMedia() async {
    if (!mounted) return;
    setState(() => _isYoutube = false);

    _localPlayer = Player();
    _localVideoController = VideoController(_localPlayer!);

    // FIX: Open with play: false
    await _localPlayer!.open(Media(widget.videoUrl), play: false);

    // Seek to start position but DO NOT call .play() automatically
    final startDuration = Duration(
      milliseconds: (widget.startSeconds * 1000).toInt(),
    );
    await _localPlayer!.seek(startDuration);

    if (mounted) {
      setState(() {
        _isLocalReady = true;
        _isReady = true;
      });
    }
  }

  void _onYoutubeReady() {
    // Just mark as ready, don't auto-seek/play forcefully here unless tapped
    setState(() => _isReady = true);
  }

  void _seekToStart() async {
    final position = Duration(
      milliseconds: (widget.startSeconds * 1000).toInt(),
    );

    if (_isYoutube && _ytController != null) {
      _ytController!.seekTo(position);
      _ytController!.play();
    } else if (!_isYoutube && _localPlayer != null) {
      await _localPlayer!.seek(position);
      await _localPlayer!.play();
    }
  }

  @override
  void dispose() {
    // 1. YouTube Disposal
    _ytController?.dispose();
    _ytController = null;

    // 2. DETACH VIDEO CONTROLLER FIRST
    // This is critical. It cuts the wire between the C++ texture and Flutter.
    // If you don't do this, C++ tries to draw a frame on a dead widget -> CRASH.
    _localVideoController = null;

    // 3. SAFE PLAYER DISPOSAL
    // We hand the player over to our Lifecycle Manager.
    // We immediately nullify our local reference.
    if (_localPlayer != null) {
      MediaLifecycle.disposeSafe(_localPlayer);
      _localPlayer = null;
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // --- YOUTUBE PLAYER ---
    if (_isYoutube && _ytController != null) {
      return Stack(
        alignment: Alignment.bottomRight,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: YoutubePlayer(
              controller: _ytController!,
              showVideoProgressIndicator: true,
              width: double.infinity,
              onReady: _onYoutubeReady,
              aspectRatio: 16 / 9,
            ),
          ),
          _buildReplayButton(),
        ],
      );
    }
    // --- LOCAL VIDEO PLAYER ---
    else if (!_isYoutube && _localVideoController != null && _isLocalReady) {
      return Stack(
        alignment: Alignment.bottomRight,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Video(
                controller: _localVideoController!,
                controls: MaterialVideoControls,
              ),
            ),
          ),
          _buildReplayButton(),
        ],
      );
    }

    // --- LOADING / ERROR STATE ---
    return Container(
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 8),
          Text(
            "Loading video...",
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildReplayButton() {
    if (!_isReady) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: FloatingActionButton.small(
        heroTag:
            "replay_srs_${widget.startSeconds}_${DateTime.now().millisecondsSinceEpoch}", // Unique tag to prevent collisions
        backgroundColor: Colors.black54,
        elevation: 0,
        onPressed: _seekToStart,
        child: const Icon(
          Icons.replay,
          color: Colors.white,
        ), // Changed to Play Arrow implies "Start"
      ),
    );
  }
}
