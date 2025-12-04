import 'package:flutter/material.dart';



// --- EXTRACTED WIDGETS ---
class ReaderTopBar extends StatelessWidget {
  final bool isDark;
  final bool isVideo;
  final String title;
  final double sliderValue;
  final double sliderMax;
  final ValueChanged<double> onSliderChanged;
  final VoidCallback onBackPressed;
  final bool showPlayButton;
  final bool isPlaying;
  final VoidCallback onPlayPressed;

  const ReaderTopBar({
    super.key,
    required this.isDark,
    required this.isVideo,
    required this.title,
    required this.sliderValue,
    required this.sliderMax,
    required this.onSliderChanged,
    required this.onBackPressed,
    required this.showPlayButton,
    required this.isPlaying,
    required this.onPlayPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          InkWell(onTap: onBackPressed, child: Icon(Icons.arrow_back, color: Colors.grey)),
          SizedBox(width: 12),
          
          // Logic: Show Title if video, otherwise show Slider
          if (isVideo)
             Expanded(child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87), overflow: TextOverflow.ellipsis, maxLines: 1))
          else
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 4,
                  thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: RoundSliderOverlayShape(overlayRadius: 14),
                  activeTrackColor: Colors.green,
                  inactiveTrackColor: isDark ? Colors.grey[800] : Colors.grey[300],
                  thumbColor: Colors.green,
                ),
                child: Slider(value: sliderValue, min: 0, max: sliderMax, onChanged: onSliderChanged),
              ),
            ),

          if (showPlayButton) ...[
            SizedBox(width: 12),
            IconButton(
              icon: Icon(isPlaying ? Icons.stop_circle_outlined : Icons.play_circle_outline, color: Colors.blue),
              onPressed: onPlayPressed,
            ),
          ],
          
          SizedBox(width: 8),
          IconButton(icon: Icon(Icons.more_horiz, color: Colors.grey), onPressed: () {}),
        ],
      ),
    );
  }
}

class ReaderModeToggleButton extends StatelessWidget {
  final bool isDark;
  final bool isSentenceMode;
  final VoidCallback onToggle;

  const ReaderModeToggleButton({
    super.key,
    required this.isDark,
    required this.isSentenceMode,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      elevation: 10,
      shadowColor: Colors.black.withOpacity(0.3),
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? Color(0xFF2C2C2C).withOpacity(0.9) : Colors.black.withOpacity(0.8),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(isSentenceMode ? Icons.notes : Icons.short_text, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                isSentenceMode ? 'All' : 'Chunks',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}