import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Renders the Local Media Controls (Play/Pause, Slider, Fullscreen toggle)
class LocalMediaControls extends StatelessWidget {
  final Player? player;
  final bool isAudio;
  final VoidCallback onToggleFullscreen;

  const LocalMediaControls({
    super.key,
    required this.player,
    required this.isAudio,
    required this.onToggleFullscreen,
  });

  @override
  Widget build(BuildContext context) {
    if (player == null) return const SizedBox.shrink();

    // StreamBuilder is better here to react to position changes without
    // forcing the parent to rebuild constantly via Timer
    return StreamBuilder<Duration>(
      stream: player!.stream.position,
      builder: (context, snapshot) {
        final duration = player!.state.duration;
        final position = snapshot.data ?? Duration.zero;
        final maxDuration = duration.inMilliseconds.toDouble();
        final currentPos = position.inMilliseconds.toDouble();

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Colors.black.withOpacity(0.8), Colors.transparent],
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  player!.state.playing ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                ),
                onPressed: () => player!.state.playing ? player!.pause() : player!.play(),
              ),
              Expanded(
                child: Slider(
                  value: currentPos.clamp(0, maxDuration),
                  min: 0,
                  max: maxDuration > 0 ? maxDuration : 1.0,
                  activeColor: Colors.blueAccent,
                  inactiveColor: Colors.white24,
                  onChanged: (v) {
                    player!.seek(Duration(milliseconds: v.toInt()));
                  },
                ),
              ),
              if (!isAudio)
                IconButton(
                  icon: const Icon(Icons.fullscreen, color: Colors.white),
                  onPressed: onToggleFullscreen,
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Renders the Header in Portrait Mode (Video or Audio Placeholder)
class ReaderMediaHeader extends StatelessWidget {
  final bool isInitializing;
  final bool isAudio;
  final bool isLocalMedia;
  final VideoController? localVideoController;
  final Player? localPlayer;
  final YoutubePlayerController? youtubeController;
  final VoidCallback onToggleFullscreen;

  const ReaderMediaHeader({
    super.key,
    required this.isInitializing,
    required this.isAudio,
    required this.isLocalMedia,
    this.localVideoController,
    this.localPlayer,
    this.youtubeController,
    required this.onToggleFullscreen,
  });

  @override
  Widget build(BuildContext context) {
    if (isInitializing) {
      return Container(
        height: isAudio ? 120 : 220,
        color: Colors.black,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    // --- LOCAL MEDIA ---
    if (isLocalMedia && localPlayer != null) {
      if (isAudio) {
        return Container(
          height: 120,
          color: Colors.grey.shade900,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Spacer(),
              const Icon(Icons.music_note, color: Colors.white54, size: 40),
              const Spacer(),
              LocalMediaControls(
                player: localPlayer,
                isAudio: true,
                onToggleFullscreen: onToggleFullscreen,
              ),
            ],
          ),
        );
      }

      // Video Player
      return Container(
        height: 220,
        color: Colors.black,
        child: Stack(
          children: [
            if (localVideoController != null)
              Center(
                child: Video(
                  controller: localVideoController!,
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: LocalMediaControls(
                player: localPlayer,
                isAudio: false,
                onToggleFullscreen: onToggleFullscreen,
              ),
            ),
          ],
        ),
      );
    }

    // --- YOUTUBE ---
    if (youtubeController != null) {
      return SizedBox(
        height: 220,
        child: YoutubePlayer(controller: youtubeController!),
      );
    }

    return const SizedBox.shrink();
  }
}