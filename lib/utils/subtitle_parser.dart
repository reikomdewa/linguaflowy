import 'dart:io';
import 'dart:convert';
import 'package:linguaflow/models/transcript_line.dart';

class SubtitleParser {
  static Future<List<TranscriptLine>> parseFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return [];

    String content;
    try {
      // Try UTF-8 first
      content = await file.readAsString();
    } catch (e) {
      // Fallback: Try decoding as Latin-1 (common for older subtitle files)
      try {
        final bytes = await file.readAsBytes();
        content = latin1.decode(bytes);
      } catch (_) {
        print("Error: Could not decode subtitle file.");
        return [];
      }
    }

    final List<TranscriptLine> lines = [];
    // Split safely handling \n, \r\n, or just \r
    final List<String> fileLines = LineSplitter.split(content).toList();
    
    // Regex for timestamps (e.g., 00:00:20,000 --> 00:00:25,000)
    // Supports both comma (,) and dot (.) for milliseconds
    final timePattern = RegExp(r'(\d{1,2}):(\d{2}):(\d{2})[,.](\d{3})\s*-->\s*(\d{1,2}):(\d{2}):(\d{2})[,.](\d{3})');

    for (int i = 0; i < fileLines.length; i++) {
      final line = fileLines[i].trim();
      
      // Look for the timestamp line
      final match = timePattern.firstMatch(line);
      
      if (match != null) {
        // Parse Start Time
        final start = _parseDuration(
          int.parse(match.group(1)!),
          int.parse(match.group(2)!),
          int.parse(match.group(3)!),
          int.parse(match.group(4)!),
        );
        
        // Parse End Time
        final end = _parseDuration(
          int.parse(match.group(5)!),
          int.parse(match.group(6)!),
          int.parse(match.group(7)!),
          int.parse(match.group(8)!),
        );

        // Collect the text following the timestamp
        StringBuffer textBuffer = StringBuffer();
        int j = i + 1;
        while (j < fileLines.length) {
          String nextLine = fileLines[j].trim();
          
          // Stop if we hit an empty line (standard SRT block end)
          if (nextLine.isEmpty) break;
          // Stop if we hit a number that looks like the next index
          if (int.tryParse(nextLine) != null && j + 1 < fileLines.length && timePattern.hasMatch(fileLines[j+1])) break;
          // Stop if we hit a timestamp directly (malformed SRT)
          if (timePattern.hasMatch(nextLine)) break;

          if (textBuffer.isNotEmpty) textBuffer.write(' ');
          textBuffer.write(nextLine);
          j++;
        }
        
        // Clean text (remove <i>, <b>, etc)
        String cleanText = _cleanSubtitleText(textBuffer.toString());
        
        if (cleanText.isNotEmpty) {
          lines.add(TranscriptLine(
            text: cleanText,
            start: start,
            end: end,
          ));
        }
        
        // Move outer loop index
        i = j - 1;
      }
    }
    
    print("Parsed ${lines.length} lines from subtitle file.");
    return lines;
  }

  static double _parseDuration(int h, int m, int s, int ms) {
    return (h * 3600) + (m * 60) + s + (ms / 1000.0);
  }

  static String _cleanSubtitleText(String text) {
    // Remove HTML-like tags
    String clean = text.replaceAll(RegExp(r'<[^>]*>'), '');
    // Remove brace tags { ... }
    clean = clean.replaceAll(RegExp(r'\{[^}]*\}'), '');
    return clean.trim();
  }
}