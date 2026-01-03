import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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
    super.key, // The Key from MorphingRoomCard (ValueKey) makes this rebuild on URL change
    required this.manager,
    required this.videoUrl,
    required this.isHost,
  });

  @override
  State<SharedYouTubePlayer> createState() => _SharedYouTubePlayerState();
}

class _SharedYouTubePlayerState extends State<SharedYouTubePlayer> {
  YoutubePlayerController? _controller;
  String? _errorMessage;

  // UI State
  bool _isControlsVisible = false;
  bool _isPlaying = true;
  bool _isBuffering = false;
  bool _isFullScreen = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  Timer? _hideTimer;
  bool _isDragging = false;

  final List<SubtitleLine> _mockSubtitles = [
    SubtitleLine(
      start: const Duration(seconds: 0),
      end: const Duration(seconds: 4),
      text: "Connecting to audio stream...",
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  // NOTE: didUpdateWidget is NOT needed for URL changes because
  // MorphingRoomCard uses a Key. This widget gets disposed and re-created.
  @override
  void didUpdateWidget(covariant SharedYouTubePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only sync if we are GUEST
    if (!widget.isHost) {
      _syncWithHost();
    }
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

    final hostPos = Duration(seconds: hostPosSeconds);
    // Don't sync if dragging or difference is small
    if (!_isDragging) {
      final diff = (hostPos.inSeconds - _currentPosition.inSeconds).abs();
      if (diff > 2) {
        _controller!.seekTo(hostPos);
      }
    }
  }

  void _initializePlayer() {
    final videoId = YoutubePlayer.convertUrlToId(widget.videoUrl);

    if (videoId == null) {
      setState(() => _errorMessage = "Invalid Video URL");
      return;
    }

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
      _isFullScreen = _controller!.value.isFullScreen;
      _currentPosition = _controller!.value.position;
      _totalDuration = _controller!.metadata.duration;
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller?.removeListener(_playerListener);
    _controller?.dispose();
    super.dispose();
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

  void _toggleFullScreen() {
    try {
      if (_controller != null) {
        _controller!.toggleFullScreenMode();
      }
    } catch (e) {
      debugPrint("Full screen toggle failed: $e");
    }
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

  // --- UI LOGIC ---

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
    return "${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}";
  }

  @override
  Widget build(BuildContext context) {
    // 1. Error State
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 40),
            const SizedBox(height: 10),
            Text(_errorMessage!, style: const TextStyle(color: Colors.white)),
          ],
        ),
      );
    }

    // 2. Loading State
    if (_controller == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.red));
    }

    return Column(
      children: [
        // 1. VIDEO PLAYER (16:9)
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            color: Colors.black,
            child: Stack(
              alignment: Alignment.center,
              fit: StackFit.expand,
              children: [
                // LAYER A: ACTUAL VIDEO
                YoutubePlayer(
                  controller: _controller!,
                  showVideoProgressIndicator: false,
                ),

                // LAYER B: TOUCH INTERCEPTOR
                GestureDetector(
                  onTap: _toggleControlsVisibility,
                  behavior: HitTestBehavior.translucent,
                  child: Container(color: Colors.transparent),
                ),

                // LAYER C: CONTROLS
                AnimatedOpacity(
                  opacity: (_isControlsVisible || !_isPlaying || _isBuffering)
                      ? 1.0
                      : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                    ),
                    child: Stack(
                      children: [
                        // C1. PLAY/PAUSE CENTER
                        Center(
                          child: _isBuffering
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : widget.isHost
                              ? Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: _hostTogglePlay,
                                    borderRadius: BorderRadius.circular(50),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.5),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        _isPlaying
                                            ? Icons.pause
                                            : Icons.play_arrow,
                                        color: Colors.white,
                                        size: 48,
                                      ),
                                    ),
                                  ),
                                )
                              : (!_isPlaying
                                    ? Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.5),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.pause,
                                          color: Colors.white,
                                          size: 48,
                                        ),
                                      )
                                    : const SizedBox()),
                        ),

                        // C2. STOP BUTTON (Host)
                        if (widget.isHost)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: IconButton(
                              tooltip: null,
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 28,
                              ),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.black45,
                              ),
                              onPressed: () {
                                context.read<RoomBloc>().add(
                                  StopYouTubeEvent(widget.manager.roomData!.id),
                                );
                              },
                            ),
                          ),

                        // C3. BOTTOM BAR
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(12, 20, 12, 8),
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
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: SizedBox(
                                    height: 20,
                                    child: CupertinoSlider(
                                      value: _currentPosition.inSeconds
                                          .toDouble()
                                          .clamp(
                                            0,
                                            _totalDuration.inSeconds.toDouble(),
                                          ),
                                      min: 0,
                                      max:
                                          _totalDuration.inSeconds.toDouble() >
                                              0
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
                                  onTap: _toggleFullScreen,
                                  child: Icon(
                                    _isFullScreen
                                        ? Icons.fullscreen_exit
                                        : Icons.fullscreen,
                                    color: Colors.white,
                                    size: 26,
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
          ),
        ),

        // 2. SUBTITLES
        SubtitleBox(
          currentPosition: _currentPosition,
          subtitles: _mockSubtitles,
        ),
      ],
    );
  }
}
