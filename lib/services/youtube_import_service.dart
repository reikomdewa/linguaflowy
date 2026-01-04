// lib/services/youtube_import_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:linguaflow/models/transcript_line.dart';
import 'package:linguaflow/utils/logger.dart';
import 'package:xml/xml.dart' as xml;

class YoutubeParser {
  Future<Map<String, dynamic>> processExtractedData(
    String jsonString,
    String targetLang,
  ) async {
    try {
      // Remove quotes if the result is wrapped in quotes
      if (jsonString.startsWith('"') && jsonString.endsWith('"')) {
        jsonString = jsonString.substring(1, jsonString.length - 1);
        // Unescape the JSON string
        jsonString = jsonString.replaceAll(r'\"', '"');
        jsonString = jsonString.replaceAll(r'\\', r'\');
      }

      final data = jsonDecode(jsonString);

      // Extract title
      final title = data['videoDetails']?['title'] ?? 'Untitled Video';

      // Extract captions
      final captionTracks =
          data['captions']?['playerCaptionsTracklistRenderer']?['captionTracks']
              as List?;

      if (captionTracks == null || captionTracks.isEmpty) {
        throw Exception('No captions available for this video');
      }

      // Find the best matching caption track
      String? subtitleUrl;

      // First try: exact language match
      for (var track in captionTracks) {
        if (track['languageCode'] == targetLang) {
          subtitleUrl = track['baseUrl'];
          break;
        }
      }

      // Second try: English fallback
      if (subtitleUrl == null) {
        for (var track in captionTracks) {
          if (track['languageCode'] == 'en') {
            subtitleUrl = track['baseUrl'];
            break;
          }
        }
      }

      // Third try: first available
      if (subtitleUrl == null && captionTracks.isNotEmpty) {
        subtitleUrl = captionTracks[0]['baseUrl'];
      }

      if (subtitleUrl == null) {
        throw Exception('Could not find subtitle URL');
      }

      print('🔍 Raw subtitle URL: "$subtitleUrl"'); // Debug

      // ⚠️ CRITICAL FIX: Ensure the URL is complete with domain
      subtitleUrl = subtitleUrl.trim();

      // Check if URL doesn't start with http:// or https://
      if (!subtitleUrl.startsWith('http://') &&
          !subtitleUrl.startsWith('https://')) {
        // It's a relative URL, prepend YouTube domain
        if (!subtitleUrl.startsWith('/')) {
          subtitleUrl = '/$subtitleUrl';
        }
        subtitleUrl = 'https://www.youtube.com$subtitleUrl';
      }

      print('✅ Fixed subtitle URL: "$subtitleUrl"'); // Debug

      // Download and parse the XML subtitles
      final transcriptLines = await _fetchAndParseSubtitles(subtitleUrl);

      // Create full content text
      final fullContent = transcriptLines.map((line) => line.text).join(' ');

      return {
        'title': title,
        'transcript': transcriptLines,
        'fullContent': fullContent,
      };
    } catch (e) {
      print('❌ Error in processExtractedData: $e');
      rethrow;
    }
  }

  Future<List<TranscriptLine>> _fetchAndParseSubtitles(String url) async {
    try {
      print('🌐 Downloading subtitles from: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to download subtitles: ${response.statusCode}');
      }

      print('✅ Subtitles downloaded (${response.body.length} chars)');

      // Parse XML
      final document = xml.XmlDocument.parse(response.body);
      final textElements = document.findAllElements('text');

      final List<TranscriptLine> lines = [];

      for (var element in textElements) {
        final startStr = element.getAttribute('start');
        final durationStr = element.getAttribute('dur');
        final text = _decodeHtmlEntities(element.innerText);

        if (startStr != null && text.isNotEmpty) {
          final start = double.tryParse(startStr) ?? 0.0;
          final duration = double.tryParse(durationStr ?? '0') ?? 0.0;

          lines.add(
            TranscriptLine(
              start: start,
              // duration: duration,
              end: start + duration,
              text: text.trim(),
            ),
          );
        }
      }

      print('✅ Parsed ${lines.length} subtitle lines');

      if (lines.isEmpty) {
        throw Exception('No subtitle lines found');
      }

      return lines;
    } catch (e) {
      print('❌ Error fetching subtitles: $e');
      rethrow;
    }
  }

  String _decodeHtmlEntities(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ')
        .replaceAll('\n', ' ')
        .trim();
  }
}
