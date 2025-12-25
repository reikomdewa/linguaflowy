import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart' as mobile;
import 'package:youtube_player_iframe/youtube_player_iframe.dart' as web;

/// A universal widget that uses 'youtube_player_flutter' on Mobile
/// and 'youtube_player_iframe' on Web.
class UniversalYoutubePlayer extends StatefulWidget {
  final String videoUrl;
  final bool autoPlay;

  const UniversalYoutubePlayer({
    super.key,
    required this.videoUrl,
    this.autoPlay = false,
  });

  @override
  State<UniversalYoutubePlayer> createState() => _UniversalYoutubePlayerState();
}

class _UniversalYoutubePlayerState extends State<UniversalYoutubePlayer> {
  // Mobile Controller
  mobile.YoutubePlayerController? _mobileController;
  
  // Web Controller
  web.YoutubePlayerController? _webController;

  @override
  void initState() {
    super.initState();
    final videoId = mobile.YoutubePlayer.convertUrlToId(widget.videoUrl) ?? '';

    if (kIsWeb) {
      // --- WEB INITIALIZATION ---
      _webController = web.YoutubePlayerController.fromVideoId(
        videoId: videoId,
        params: const web.YoutubePlayerParams(
          showControls: true,
          showFullscreenButton: true,
          mute: false,
        ),
      );
      
      if (widget.autoPlay) {
        _webController?.playVideo();
      }
    } else {
      // --- MOBILE INITIALIZATION ---
      _mobileController = mobile.YoutubePlayerController(
        initialVideoId: videoId,
        flags: mobile.YoutubePlayerFlags(
          autoPlay: widget.autoPlay,
          mute: false,
          enableCaption: true,
        ),
      );
    }
  }

  @override
  void dispose() {
    if (kIsWeb) {
      _webController?.close();
    } else {
      _mobileController?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      // --- RENDER FOR WEB (Iframe) ---
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: web.YoutubePlayer(
          controller: _webController!,
          aspectRatio: 16 / 9,
        ),
      );
    } else {
      // --- RENDER FOR MOBILE (Native) ---
      return mobile.YoutubePlayerBuilder(
        player: mobile.YoutubePlayer(
          controller: _mobileController!,
          showVideoProgressIndicator: true,
          progressIndicatorColor: Colors.red,
        ),
        builder: (context, player) {
          return Column(
            children: [
              // This builder handles full-screen properly on mobile
              player,
            ],
          );
        },
      );
    }
  }
}