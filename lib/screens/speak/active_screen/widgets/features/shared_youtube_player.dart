import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:linguaflow/screens/speak/active_screen/managers/room_global_manager.dart';
import 'package:linguaflow/blocs/speak/room/room_bloc.dart';
import 'package:linguaflow/blocs/speak/room/room_event.dart';
import 'subtitle_box.dart';

class SharedYouTubePlayer extends StatefulWidget {
  final RoomGlobalManager manager;
  final String videoUrl;
  final bool isHost;

  const SharedYouTubePlayer({
    super.key,
    required this.manager,
    required this.videoUrl,
    required this.isHost,
  });

  @override
  State<SharedYouTubePlayer> createState() => _SharedYouTubePlayerState();
}

class _SharedYouTubePlayerState extends State<SharedYouTubePlayer>
    with WidgetsBindingObserver {
  YoutubePlayerController? _controller;

  bool _isControlsVisible = false;
  bool _isPlaying = true;
  bool _isBuffering = false;
  bool _isFullScreen = false;

  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  Timer? _hideTimer;
  bool _isDragging = false;

  List<SubtitleLine> _subtitles = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _generateMockSubtitles();
    _initializePlayer();
  }

  void _generateMockSubtitles() {
    _subtitles = List.generate(500, (index) {
      final startSeconds = index * 5;
      return SubtitleLine(
        start: Duration(seconds: startSeconds),
        end: Duration(seconds: startSeconds + 4),
        text: "coming soon ${startSeconds}s.",
      );
    });
  }

  @override
  void didUpdateWidget(covariant SharedYouTubePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _loadNewVideo(widget.videoUrl);
    }
    if (!widget.isHost) {
      _syncWithHost();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_isFullScreen) {
      _exitFullScreenSystem();
    }
    _hideTimer?.cancel();
    _controller?.removeListener(_playerListener);
    _controller?.dispose();
    super.dispose();
  }

  void _syncWithHost() {
    final state = widget.manager.roomData?.activeFeatureState;
    if (state == null || _controller == null) return;

    final hostStatus = state['status'] as String?;
    final hostPosSeconds = state['position'] as int?;

    if (hostStatus == null || hostPosSeconds == null) return;

    if (hostStatus == 'paused' && _isPlaying) {
      _controller!.pause();
    } else if (hostStatus == 'playing' && !_isPlaying) {
      _controller!.play();
    }

    if (!_isDragging) {
      final hostPos = Duration(seconds: hostPosSeconds);
      final diff = (hostPos.inSeconds - _currentPosition.inSeconds).abs();
      if (diff > 2) {
        _controller!.seekTo(hostPos);
      }
    }
  }

  void _initializePlayer() {
    final videoId = YoutubePlayer.convertUrlToId(widget.videoUrl);
    if (videoId == null) return;

    _controller = YoutubePlayerController(
      initialVideoId: videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        disableDragSeek: false,
        loop: false,
        isLive: false,
        forceHD: true,
        enableCaption: false,
        hideControls: true,
      ),
    )..addListener(_playerListener);
  }

  void _playerListener() {
    if (_controller == null || !mounted || _isDragging) return;
    setState(() {
      _isPlaying = _controller!.value.isPlaying;
      _currentPosition = _controller!.value.position;
      _totalDuration = _controller!.metadata.duration;
    });
  }

  void _loadNewVideo(String url) {
    final videoId = YoutubePlayer.convertUrlToId(url);
    if (videoId != null && _controller != null) {
      _controller!.load(videoId);
      _controller!.play();
    }
  }

  // --- ACTIONS ---

  void _hostTogglePlay() {
    if (!widget.isHost || _controller == null) return;
    if (_isPlaying) {
      _controller!.pause();
      _sendSyncEvent('paused', _currentPosition.inSeconds);
    } else {
      _controller!.play();
      _sendSyncEvent('playing', _currentPosition.inSeconds);
    }
    _resetHideTimer();
  }

  void _hostSeekTo(double value) {
    if (!widget.isHost || _controller == null) return;
    final newPos = Duration(seconds: value.toInt());
    _controller!.seekTo(newPos);
    _sendSyncEvent(_isPlaying ? 'playing' : 'paused', value.toInt());
    _resetHideTimer();
  }

  void _sendSyncEvent(String status, int seconds) {
    context.read<RoomBloc>().add(
      SyncYouTubeStateEvent(
        roomId: widget.manager.roomData!.id,
        status: status,
        positionSeconds: seconds,
      ),
    );
  }

  // --- FULL SCREEN LOGIC ---

  void _toggleCustomFullScreen() {
    if (!_isFullScreen) {
      setState(() => _isFullScreen = true);

      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

      Navigator.of(context, rootNavigator: true)
          .push(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) {
                return _buildFullscreenScaffold();
              },
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    return FadeTransition(opacity: animation, child: child);
                  },
            ),
          )
          .then((_) {
            _exitFullScreenSystem();
          });
    } else {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  void _exitFullScreenSystem() {
    if (!mounted) return;
    setState(() => _isFullScreen = false);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
  }

  // --- CONTROLS VISIBILITY ---

  void _toggleControlsVisibility() {
    setState(() => _isControlsVisible = !_isControlsVisible);
    if (_isControlsVisible) {
      _resetHideTimer();
    } else {
      _hideTimer?.cancel();
    }
  }

  void _resetHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _isPlaying && !_isDragging) {
        setState(() => _isControlsVisible = false);
      }
    });
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    if (d.inHours > 0) {
      return "${d.inHours}:${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}";
    }
    return "${d.inMinutes}:${twoDigits(d.inSeconds.remainder(60))}";
  }

  // --- WIDGET BUILDERS ---

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.red));
    }

    if (_isFullScreen) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Icon(Icons.fullscreen, color: Colors.white24, size: 50),
        ),
      );
    }

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: _buildPlayerStack(isFullScreen: false),
        ),
        // SubtitleBox(currentPosition: _currentPosition, subtitles: _subtitles),
      ],
    );
  }

  Widget _buildFullscreenScaffold() {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _toggleCustomFullScreen();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            alignment: Alignment.center,
            children: [
              Center(
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _buildPlayerStack(isFullScreen: true),
                ),
              ),
              // Floating Subtitles in Landscape
              if (_isControlsVisible == false || _isPlaying)
                Positioned(
                  bottom: _isControlsVisible ? 80 : 20,
                  left: 60,
                  right: 60,
                  child: Center(child: _buildSubtitleText()),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerStack({required bool isFullScreen}) {
    return Container(
      color: Colors.black,
      child: Stack(
        alignment: Alignment.center,
        fit: StackFit.expand,
        children: [
          YoutubePlayer(
            controller: _controller!,
            showVideoProgressIndicator: false,
          ),

          GestureDetector(
            onTap: _toggleControlsVisibility,
            behavior: HitTestBehavior.translucent,
            child: Container(color: Colors.transparent),
          ),

          AnimatedOpacity(
            opacity: (_isControlsVisible || !_isPlaying || _isBuffering)
                ? 1.0
                : 0.0,
            duration: const Duration(milliseconds: 300),
            child: Container(
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.4)),
              child: Stack(
                children: [
                  Center(
                    child: _isBuffering
                        ? const CircularProgressIndicator(color: Colors.white)
                        : widget.isHost
                        ? Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _hostTogglePlay,
                              borderRadius: BorderRadius.circular(50),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _isPlaying ? Icons.pause : Icons.play_arrow,
                                  color: Colors.white,
                                  size: isFullScreen ? 60 : 40,
                                ),
                              ),
                            ),
                          )
                        : (!_isPlaying
                              ? Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.pause,
                                    color: Colors.white,
                                    size: isFullScreen ? 60 : 40,
                                  ),
                                )
                              : const SizedBox()),
                  ),

                  if (widget.isHost)
                    Positioned(
                      top: 16,
                      right: 16,
                      child: IconButton(
                        tooltip: null, // FIX: Prevent Overlay Crash
                        icon: const Icon(Icons.close, color: Colors.white),
                        iconSize: isFullScreen ? 32 : 24,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black54,
                        ),
                        onPressed: () {
                          if (_isFullScreen) Navigator.of(context).pop();
                          context.read<RoomBloc>().add(
                            StopYouTubeEvent(widget.manager.roomData!.id),
                          );
                        },
                      ),
                    ),

                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isFullScreen ? 24 : 12,
                        vertical: isFullScreen ? 16 : 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.8),
                          ],
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            "${_formatDuration(_currentPosition)} / ${_formatDuration(_totalDuration)}",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isFullScreen ? 14 : 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 20,
                              // FIX: Use CupertinoSlider to avoid "No Overlay widget found"
                              child: CupertinoSlider(
                                value: _currentPosition.inSeconds
                                    .toDouble()
                                    .clamp(
                                      0,
                                      _totalDuration.inSeconds.toDouble(),
                                    ),
                                min: 0,
                                max: _totalDuration.inSeconds.toDouble() > 0
                                    ? _totalDuration.inSeconds.toDouble()
                                    : 1.0,
                                activeColor: const Color(0xFFFF0000),
                                thumbColor: widget.isHost
                                    ? const Color(0xFFFF0000)
                                    : Colors.transparent,
                                onChangeStart: (_) {
                                  if (widget.isHost) {
                                    _isDragging = true;
                                    _hideTimer?.cancel();
                                  }
                                },
                                onChanged: (val) {
                                  if (widget.isHost)
                                    setState(
                                      () => _currentPosition = Duration(
                                        seconds: val.toInt(),
                                      ),
                                    );
                                },
                                onChangeEnd: (val) {
                                  if (widget.isHost) {
                                    _isDragging = false;
                                    _hostSeekTo(val);
                                  }
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: _toggleCustomFullScreen,
                            child: Icon(
                              _isFullScreen
                                  ? Icons.fullscreen_exit
                                  : Icons.fullscreen,
                              color: Colors.white,
                              size: isFullScreen ? 32 : 24,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtitleText() {
    final currentLine = _subtitles.firstWhere(
      (s) => _currentPosition >= s.start && _currentPosition <= s.end,
      orElse: () =>
          SubtitleLine(start: Duration.zero, end: Duration.zero, text: ""),
    );

    if (currentLine.text.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        currentLine.text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.yellow,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          shadows: [
            Shadow(offset: Offset(0, 1), blurRadius: 4, color: Colors.black),
          ],
        ),
      ),
    );
  }
}
