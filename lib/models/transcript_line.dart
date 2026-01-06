class TranscriptLine {
  final String text;
  final double start;
  final double end;

  TranscriptLine({required this.text, required this.start, required this.end});

  factory TranscriptLine.fromMap(Map<String, dynamic> map) {
    return TranscriptLine(
      text: map['text'] ?? '',
      // Ensure we handle int or double from JSON
      start: (map['start'] as num).toDouble(),
      end: (map['end'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {'text': text, 'start': start, 'end': end};
  }
}