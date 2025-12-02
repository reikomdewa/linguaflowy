import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:http/http.dart' as http;
import 'package:linguaflow/models/lesson_model.dart';

class CloudLessonService {
  // 🔴 YOUR GOOGLE CLOUD API KEY (For Searching)
  static const String _googleApiKey = 'YOUR_GOOGLE_API_KEY_HERE';
  static const String _googleBaseUrl = 'https://www.googleapis.com/youtube/v3';

  // Instance of Firebase Functions
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  String _getSearchQuery(String languageCode) {
    switch (languageCode) {
      case 'es': return 'Spanish comprehensible input subtitles';
      case 'fr': return 'French comprehensible input subtitles';
      case 'de': return 'German comprehensible input subtitles';
      case 'it': return 'Italian comprehensible input subtitles';
      case 'pt': return 'Portuguese comprehensible input subtitles';
      case 'ja': return 'Japanese comprehensible input subtitles';
      default: return 'English learning stories';
    }
  }

  Future<List<LessonModel>> fetchRecommendedVideos(String languageCode) async {
    // 1. SEARCH VIDEO METADATA (Official API)
    // We use the official API because it never gets blocked for searching.
    try {
      if (_googleApiKey == 'YOUR_GOOGLE_API_KEY_HERE') {
        print("⚠️ API Key missing in CloudLessonService");
        return _getFallbackLessons(languageCode);
      }

      final query = _getSearchQuery(languageCode);
      // videoCaption=closedCaption ensures we only find videos that actually have text
      final searchUrl = '$_googleBaseUrl/search?part=snippet&q=$query&type=video&videoCaption=closedCaption&maxResults=5&key=$_googleApiKey';
      
      print("🚀 SEARCHING: $query");
      final response = await http.get(Uri.parse(searchUrl));

      if (response.statusCode != 200) {
        print("❌ Search Error: ${response.body}");
        return _getFallbackLessons(languageCode);
      }

      final data = json.decode(response.body);
      List<LessonModel> lessons = [];

      // 2. FETCH TRANSCRIPTS (Cloud Function)
      for (var item in data['items']) {
        try {
          final videoId = item['id']['videoId'];
          final snippet = item['snippet'];
          final title = snippet['title'];
          final thumb = snippet['thumbnails']['high']['url'];

          // Call the Cloud Function
          final lesson = await _fetchTranscriptFromCloud(videoId, title, thumb, languageCode);
          
          if (lesson != null) {
            lessons.add(lesson);
          }
        } catch (e) {
          print("   ⚠️ Skipped video: $e");
        }
      }

      if (lessons.isEmpty) return _getFallbackLessons(languageCode);
      
      print("✅ FOUND ${lessons.length} LESSONS via Cloud Functions");
      return lessons;

    } catch (e) {
      print("❌ CRITICAL ERROR: $e");
      return _getFallbackLessons(languageCode);
    }
  }

  Future<LessonModel?> _fetchTranscriptFromCloud(String videoId, String title, String imageUrl, String langCode) async {
    try {
      print("   ☁️ Calling Cloud Function for: $title");

      // CALL FIREBASE FUNCTION
      final result = await _functions.httpsCallable('get_transcript').call({
        "videoId": videoId,
        "lang": langCode,
      });

      final data = result.data as Map<dynamic, dynamic>;

      if (data['success'] == false) {
        print("      ⚠️ Cloud Error: ${data['error']}");
        return null;
      }

      final content = data['content'] as String;
      if (content.length < 50) return null;

      return LessonModel(
        id: 'yt_$videoId',
        userId: 'system',
        title: title,
        language: langCode,
        content: content,
        sentences: _splitIntoSentences(content),
        createdAt: DateTime.now(),
        imageUrl: imageUrl,
        type: 'video', // This triggers the video player in ReaderScreen
        difficulty: _analyzeDifficulty(content),
        videoUrl: 'https://youtube.com/watch?v=$videoId',
        isFavorite: false,
      );

    } catch (e) {
      print("      ❌ Function Call Failed: $e");
      return null;
    }
  }

  // --- UTILITIES ---
  String _analyzeDifficulty(String text) {
    final words = text.split(' ');
    if (words.isEmpty) return 'intermediate';
    final avg = words.join().length / words.length;
    if (avg < 4.5) return 'beginner';
    if (avg > 6.0) return 'advanced';
    return 'intermediate';
  }

  List<String> _splitIntoSentences(String text) {
    return text.split(RegExp(r'[.!?]+')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  }

  List<LessonModel> _getFallbackLessons(String lang) {
    // Keep your fallback data here just in case!
    return [
       LessonModel(
        id: 'yt_fallback_1',
        userId: 'system',
        title: 'Cloud Function Fallback Demo',
        language: lang,
        content: "This is displayed because the Cloud Function failed or API key is missing.",
        sentences: ["This is displayed because the Cloud Function failed."],
        createdAt: DateTime.now(),
        imageUrl: 'https://img.youtube.com/vi/hdjX3b2d1yE/hqdefault.jpg',
        type: 'video',
        difficulty: 'beginner',
        videoUrl: 'https://youtube.com/watch?v=hdjX3b2d1yE',
        isFavorite: false,
      ),
    ];
  }
}