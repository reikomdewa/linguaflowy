import 'package:flutter/material.dart';
import 'package:linguaflow/screens/reader/reader_utils.dart';

class VideoControlsOverlay extends StatelessWidget {
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final bool showControls;
  final VoidCallback onPlayPause;
  final Function(int) onSeekRelative;
  final Function(Duration) onSeekTo;
  final VoidCallback onToggleFullscreen;

  const VideoControlsOverlay({
    super.key,
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.showControls,
    required this.onPlayPause,
    required this.onSeekRelative,
    required this.onSeekTo,
    required this.onToggleFullscreen,
  });

  @override
  Widget build(BuildContext context) {
    // Ensure duration isn't zero to prevent division errors
    final effectiveDuration = duration.inSeconds == 0 
        ? const Duration(seconds: 1) 
        : duration;

    return AnimatedOpacity(
      opacity: showControls ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: IgnorePointer(
        ignoring: !showControls,
        child: Container(
          color: Colors.black.withValues(alpha: 0.4), // Dim overlay
          child: Stack(
            children: [
              // CENTER CONTROLS (Back 10, Play/Pause, Fwd 10)
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      iconSize: 40,
                      icon: const Icon(Icons.replay_10, color: Colors.white),
                      onPressed: () => onSeekRelative(-10),
                    ),
                    const SizedBox(width: 40),
                    Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black45,
                      ),
                      child: IconButton(
                        iconSize: 64,
                        icon: Icon(
                          isPlaying
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_fill,
                          color: Colors.white,
                        ),
                        onPressed: onPlayPause,
                      ),
                    ),
                    const SizedBox(width: 40),
                    IconButton(
                      iconSize: 40,
                      icon: const Icon(Icons.forward_10, color: Colors.white),
                      onPressed: () => onSeekRelative(10),
                    ),
                  ],
                ),
              ),

              // BOTTOM PROGRESS BAR
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black87, Colors.transparent],
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Text(
                              "${ReaderUtils.formatDuration(position)} / ${ReaderUtils.formatDuration(effectiveDuration)}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(
                                Icons.fullscreen_exit,
                                color: Colors.white,
                              ),
                              onPressed: onToggleFullscreen,
                            ),
                          ],
                        ),
                        SizedBox(
                          height: 20,
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: Colors.red, // YouTube Red
                              inactiveTrackColor: Colors.white24,
                              thumbColor: Colors.red,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6,
                              ),
                              trackHeight: 2,
                            ),
                            child: Slider(
                              value: position.inMilliseconds.toDouble().clamp(
                                0,
                                effectiveDuration.inMilliseconds.toDouble(),
                              ),
                              min: 0,
                              max: effectiveDuration.inMilliseconds.toDouble(),
                              onChanged: (v) {
                                final p = Duration(milliseconds: v.toInt());
                                onSeekTo(p);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}