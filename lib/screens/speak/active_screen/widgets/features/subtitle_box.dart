import 'package:flutter/material.dart';

class SubtitleLine {
  final Duration start;
  final Duration end;
  final String text;

  SubtitleLine({required this.start, required this.end, required this.text});
}

class SubtitleBox extends StatelessWidget {
  final Duration currentPosition;
  // In a real app, you would populate this list from Whisper or an API
  final List<SubtitleLine> subtitles; 

  const SubtitleBox({
    super.key,
    required this.currentPosition,
    required this.subtitles,
  });

  @override
  Widget build(BuildContext context) {
    // Find the subtitle that matches the current time
    final currentLine = subtitles.firstWhere(
      (s) => currentPosition >= s.start && currentPosition <= s.end,
      orElse: () => SubtitleLine(start: Duration.zero, end: Duration.zero, text: ""),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF121212), // Black background
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      constraints: const BoxConstraints(minHeight: 80),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (currentLine.text.isNotEmpty)
            Text(
              currentLine.text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.yellowAccent, // Classic subtitle color
                fontSize: 16,
                fontWeight: FontWeight.w600,
                shadows: [
                  Shadow(offset: Offset(1, 1), blurRadius: 2, color: Colors.black),
                ],
              ),
            )
          else
            const Text(
              "Listening...", 
              style: TextStyle(color: Colors.white24, fontStyle: FontStyle.italic),
            ),
        ],
      ),
    );
  }
}