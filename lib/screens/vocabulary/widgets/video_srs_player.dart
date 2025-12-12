import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
// Add imports for MediaKit if using local video
// import 'package:media_kit/media_kit.dart';
// import 'package:media_kit_video/media_kit_video.dart';

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
  YoutubePlayerController? _ytController;
  Timer? _loopTimer;
  bool _isYoutube = false;

  @override
  void initState() {
    super.initState();
    _checkTypeAndInit();
  }

  void _checkTypeAndInit() {
    if (widget.videoUrl.contains('youtube.com') || widget.videoUrl.contains('youtu.be')) {
      _isYoutube = true;
      final videoId = YoutubePlayer.convertUrlToId(widget.videoUrl);
      if (videoId != null) {
        _ytController = YoutubePlayerController(
          initialVideoId: videoId,
          flags: const YoutubePlayerFlags(
            autoPlay: true,
            hideControls: true, // We want pure immersion, no distractions
            mute: false,
            startAt: 0, // Will seek in listener
          ),
        );
        
        // Add listener for looping logic
        _ytController!.addListener(_youtubeLoopListener);
      }
    } else {
      // TODO: Implement MediaKit logic for local files here similar to ReaderScreen
    }
  }

  void _youtubeLoopListener() {
    if (_ytController == null || !_ytController!.value.isReady) return;

    final currentPos = _ytController!.value.position.inMilliseconds / 1000.0;
    
    // If we haven't reached the start yet (initial load)
    if (currentPos < widget.startSeconds) {
      _ytController!.seekTo(Duration(milliseconds: (widget.startSeconds * 1000).toInt()));
      _ytController!.play();
    } 
    // If we pass the end, loop back
    else if (currentPos > widget.endSeconds) {
      _ytController!.seekTo(Duration(milliseconds: (widget.startSeconds * 1000).toInt()));
    }
  }

  @override
  void dispose() {
    _ytController?.removeListener(_youtubeLoopListener);
    _ytController?.dispose();
    _loopTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isYoutube && _ytController != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: YoutubePlayer(
          controller: _ytController!,
          showVideoProgressIndicator: false,
          width: double.infinity,
        ),
      );
    }
    
    // Fallback for local or error
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      child: const Icon(Icons.videocam_off, color: Colors.white),
    );
  }
}