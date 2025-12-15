import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final bool isStandalone;

  const VideoSRSPlayer({
    super.key,
    required this.videoUrl,
    required this.startSeconds,
    required this.endSeconds,
    this.isStandalone = false,
  });

  @override
  State<VideoSRSPlayer> createState() => _VideoSRSPlayerState();
}

class _VideoSRSPlayerState extends State<VideoSRSPlayer> {
  // YouTube State
  YoutubePlayerController? _ytController;
  bool _isYoutube = false;
  
  // Hand-off State
  bool _isFullScreen = false;

  // Local Media State
  Player? _localPlayer;
  VideoController? _localVideoController;
  bool _isLocalReady = false;

  bool _isReady = false;

  static const int kVocabularyTabIndex = 2;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // If we are currently swapping to/from full screen, ignore auto-pause logic
    if (_isFullScreen) return;

    if (widget.isStandalone) {
      if (!_isReady && _localPlayer == null && _ytController == null) {
        _checkTypeAndInit();
      }
      return;
    }

    final activeTab = ActiveTabNotifier.of(context);

    if (activeTab == kVocabularyTabIndex &&
        !_isReady &&
        _localPlayer == null &&
        _ytController == null) {
      _checkTypeAndInit();
    } else if (activeTab != kVocabularyTabIndex) {
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

  Future<void> _checkTypeAndInit({int? startAt}) async {
    if (widget.videoUrl.toLowerCase().contains('youtube.com') ||
        widget.videoUrl.toLowerCase().contains('youtu.be')) {
      _initYoutube(startAt: startAt);
    } else {
      _initLocalMedia(startAt: startAt);
    }
  }

  // --- YOUTUBE INIT ---
  void _initYoutube({int? startAt}) {
    if (!mounted) return;
    
    _ytController?.dispose();
    
    setState(() {
      _isYoutube = true;
      _isReady = false; 
    });

    final videoId = YoutubePlayer.convertUrlToId(widget.videoUrl);
    if (videoId != null) {
      _ytController = YoutubePlayerController(
        initialVideoId: videoId,
        flags: YoutubePlayerFlags(
          autoPlay: startAt != null || widget.isStandalone,
          hideControls: false,
          mute: false,
          startAt: startAt ?? widget.startSeconds.toInt(),
          forceHD: false,
          disableDragSeek: false,
        ),
      );
    }
  }

  // --- LOCAL MEDIA INIT ---
  Future<void> _initLocalMedia({int? startAt}) async {
    if (!mounted) return;
    
    if (_localPlayer != null) {
      await _localPlayer!.dispose();
    }

    setState(() {
      _isYoutube = false;
      _isLocalReady = false;
      _isReady = false;
    });

    try {
      _localPlayer = Player();
      _localVideoController = VideoController(_localPlayer!);

      await _localPlayer!.open(
        Media(widget.videoUrl),
        play: (startAt != null || widget.isStandalone),
      );

      final startDuration = Duration(
        milliseconds: ((startAt != null ? startAt.toDouble() : widget.startSeconds) * 1000).toInt(),
      );
      await _localPlayer!.seek(startDuration);

      if (mounted) {
        setState(() {
          _isLocalReady = true;
          _isReady = true;
        });
      }
    } catch (e) {
      debugPrint("Error loading local media: $e");
    }
  }

  void _onYoutubeReady() {
    if (mounted) {
      setState(() => _isReady = true);
    }
  }

  // --- FULL SCREEN LOGIC ---
  void _enterYoutubeFullScreen() async {
    if (_ytController == null) return;

    // 1. Capture Data & Dispose Current
    final currentPos = _ytController!.value.position.inSeconds;
    final videoId = YoutubePlayer.convertUrlToId(widget.videoUrl);

    if (videoId == null) return;

    _ytController!.pause(); 
    _ytController!.dispose();
    _ytController = null;

    setState(() {
      _isFullScreen = true;
      _isReady = false; 
    });

    // 2. Hide System UI (Immersive Mode) & Force Landscape
    // This ensures the video expands to cover the notch/status bar
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // 3. Push Full Screen Page
    final resultPos = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (context) => _FullScreenYoutubePage(
          videoId: videoId,
          startAt: currentPos,
        ),
      ),
    );

    // 4. Restore System UI & Portrait
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    // 5. Re-init Embedded Player
    if (mounted) {
      setState(() {
        _isFullScreen = false;
      });
      _initYoutube(startAt: resultPos ?? currentPos);
    }
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
    _ytController?.dispose();
    _localVideoController = null;
    if (_localPlayer != null) {
      MediaLifecycle.disposeSafe(_localPlayer);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isFullScreen) {
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(color: Colors.white),
      );
    }

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
              bottomActions: [
                CurrentPosition(),
                ProgressBar(isExpanded: true),
                RemainingDuration(),
                const PlaybackSpeedButton(),
                // Custom Full Screen Icon (Expand)
                IconButton(
                  icon: const Icon(Icons.fullscreen, color: Colors.white),
                  onPressed: _enterYoutubeFullScreen,
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 50,
            right: 8,
            child: _buildReplayButton(),
          ),
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
          Positioned(
            bottom: 50,
            right: 8,
            child: _buildReplayButton(),
          ),
        ],
      );
    }

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
    return FloatingActionButton.small(
      heroTag: "replay_srs_${widget.startSeconds}_${DateTime.now().millisecondsSinceEpoch}",
      backgroundColor: Colors.black54,
      elevation: 0,
      onPressed: _seekToStart,
      child: const Icon(Icons.replay, color: Colors.white),
    );
  }
}

// --- FULL SCREEN PAGE ---
class _FullScreenYoutubePage extends StatefulWidget {
  final String videoId;
  final int startAt;

  const _FullScreenYoutubePage({
    required this.videoId,
    required this.startAt,
  });

  @override
  State<_FullScreenYoutubePage> createState() => _FullScreenYoutubePageState();
}

class _FullScreenYoutubePageState extends State<_FullScreenYoutubePage> {
  late YoutubePlayerController _fsController;

  @override
  void initState() {
    super.initState();
    _fsController = YoutubePlayerController(
      initialVideoId: widget.videoId,
      flags: YoutubePlayerFlags(
        autoPlay: true,
        startAt: widget.startAt,
        hideControls: false,
        mute: false,
        forceHD: false,
      ),
    );
  }

  @override
  void dispose() {
    _fsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _fsController.value.position.inSeconds);
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        // We use Center to ensure it respects aspect ratio, but fills available space
        body: Center(
          child: YoutubePlayer(
            controller: _fsController,
            showVideoProgressIndicator: true,
            // Width must be explicit in full screen to ensure controls stretch
            width: MediaQuery.of(context).size.width,
            bottomActions: [
              CurrentPosition(),
              ProgressBar(isExpanded: true),
              RemainingDuration(),
              const PlaybackSpeedButton(),
              // Exit Full Screen Icon (Collapse)
              IconButton(
                icon: const Icon(Icons.fullscreen_exit, color: Colors.white),
                onPressed: () {
                  Navigator.pop(context, _fsController.value.position.inSeconds);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}