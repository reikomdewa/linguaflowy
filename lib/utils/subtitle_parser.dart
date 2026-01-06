import 'dart:io';
import 'dart:convert';
import 'package:linguaflow/models/transcript_line.dart';

class SubtitleParser {
  static Future<List<TranscriptLine>> parseFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return [];

    String content;
    try {
      content = await file.readAsString();
    } catch (e) {
      try {
        final bytes = await file.readAsBytes();
        content = latin1.decode(bytes);
      } catch (_) {
        return [];
      }
    }

    final List<TranscriptLine> lines = [];
    final List<String> fileLines = LineSplitter.split(content).toList();
    
    // Regex that handles HH:MM:SS,mmm OR MM:SS,mmm
    // Group 1: Hours (Optional)
    // Group 2: Minutes
    // Group 3: Seconds
    // Group 4: Millis
    final timestampRegex = RegExp(r'(?:(\d{1,2}):)?(\d{1,2}):(\d{2})[,.](\d{3})');
    final arrowRegex = RegExp(r'\s*-->\s*');

    for (int i = 0; i < fileLines.length; i++) {
      final line = fileLines[i].trim();
      
      // Check if line contains the arrow "-->"
      if (!line.contains('-->')) continue;

      final parts = line.split(arrowRegex);
      if (parts.length != 2) continue;

      final startMatch = timestampRegex.firstMatch(parts[0]);
      final endMatch = timestampRegex.firstMatch(parts[1]);

      if (startMatch != null && endMatch != null) {
        final start = _parseMatch(startMatch);
        final end = _parseMatch(endMatch);

        StringBuffer textBuffer = StringBuffer();
        int j = i + 1;
        while (j < fileLines.length) {
          String nextLine = fileLines[j].trim();
          if (nextLine.isEmpty) break;
          // Stop if next line looks like index or timestamp
          if (int.tryParse(nextLine) != null && j+1 < fileLines.length && fileLines[j+1].contains('-->')) break;
          
          if (textBuffer.isNotEmpty) textBuffer.write(' ');
          textBuffer.write(nextLine);
          j++;
        }
        
        String cleanText = _cleanSubtitleText(textBuffer.toString());
        if (cleanText.isNotEmpty) {
          lines.add(TranscriptLine(text: cleanText, start: start, end: end));
        }
        i = j - 1; // Advance loop
      }
    }

    // 1. Sort lines by start time
    lines.sort((a, b) => a.start.compareTo(b.start));

    // 2. Fix Overlaps
    for (int i = 0; i < lines.length - 1; i++) {
      if (lines[i].end > lines[i+1].start) {
        lines[i] = TranscriptLine(
          text: lines[i].text,
          start: lines[i].start,
          end: lines[i+1].start - 0.05, // Slight gap
        );
      }
    }
    
    return lines;
  }

  static double _parseMatch(RegExpMatch match) {
    int h = match.group(1) != null ? int.parse(match.group(1)!) : 0;
    int m = int.parse(match.group(2)!);
    int s = int.parse(match.group(3)!);
    int ms = int.parse(match.group(4)!);
    
    return (h * 3600) + (m * 60) + s + (ms / 1000.0);
  }

  static String _cleanSubtitleText(String text) {
    String clean = text.replaceAll(RegExp(r'<[^>]*>'), ''); // HTML
    clean = clean.replaceAll(RegExp(r'\{[^}]*\}'), ''); // Braces
    return clean.trim();
  }
}