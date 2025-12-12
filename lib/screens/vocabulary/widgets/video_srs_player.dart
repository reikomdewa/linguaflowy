import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

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

  bool _isReady = false; // General ready state for UI

  @override
  void initState() {
    super.initState();
    _checkTypeAndInit();
  }

  Future<void> _checkTypeAndInit() async {
    if (widget.videoUrl.toLowerCase().contains('youtube.com') || 
        widget.videoUrl.toLowerCase().contains('youtu.be')) {
      _initYoutube();
    } else {
      _initLocalMedia();
    }
  }

  void _initYoutube() {
    setState(() => _isYoutube = true);
    final videoId = YoutubePlayer.convertUrlToId(widget.videoUrl);
    if (videoId != null) {
      _ytController = YoutubePlayerController(
        initialVideoId: videoId,
        flags: YoutubePlayerFlags(
          autoPlay: true,
          hideControls: false, 
          mute: false,
          startAt: widget.startSeconds.toInt(),
        ),
      );
    }
  }

  Future<void> _initLocalMedia() async {
    setState(() => _isYoutube = false);
    
    // Create MediaKit Player
    _localPlayer = Player();
    _localVideoController = VideoController(_localPlayer!);

    // Open file
    await _localPlayer!.open(Media(widget.videoUrl), play: false);
    
    // Seek to start position
    final startDuration = Duration(milliseconds: (widget.startSeconds * 1000).toInt());
    await _localPlayer!.seek(startDuration);
    
    // Play
    await _localPlayer!.play();

    if (mounted) {
      setState(() {
        _isLocalReady = true;
        _isReady = true;
      });
    }
  }

  void _onYoutubeReady() {
    setState(() => _isReady = true);
    _seekToStart();
  }

  void _seekToStart() async {
    final position = Duration(milliseconds: (widget.startSeconds * 1000).toInt());

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
    _localPlayer?.dispose();
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
                // Use minimal controls for the card
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
          Text("Loading video...", style: TextStyle(color: Colors.grey, fontSize: 12))
        ],
      ),
    );
  }

  Widget _buildReplayButton() {
    if (!_isReady) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: FloatingActionButton.small(
        heroTag: "replay_srs_${widget.startSeconds}", // Unique tag
        backgroundColor: Colors.black54,
        elevation: 0,
        child: const Icon(Icons.replay, color: Colors.white),
        onPressed: _seekToStart,
      ),
    );
  }
}