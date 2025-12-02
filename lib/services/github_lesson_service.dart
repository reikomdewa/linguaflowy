import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:linguaflow/models/lesson_model.dart';

class GitHubLessonService {
  // Update these with your exact details
  static const String _repoOwner = 'reikomdewa'; 
  static const String _repoName = 'linguaflowy'; 
  static const String _branch = 'master'; // Your branch is 'master', not 'main'
  
  // This points to the raw file in your repository
  String get _baseUrl => 'https://raw.githubusercontent.com/$_repoOwner/$_repoName/$_branch/data';

  Future<List<LessonModel>> fetchRecommendedVideos(String languageCode) async {
    try {
      final url = '$_baseUrl/lessons_$languageCode.json';
      
      print("📥 Fetching Feed: $url");
      
      // We add a timestamp (?t=...) to force the app to ignore cache and get the latest file
      final uri = Uri.parse('$url?t=${DateTime.now().millisecondsSinceEpoch}');
      
      final response = await http.get(uri);

      if (response.statusCode != 200) {
        print("⚠️ Feed not found (Status ${response.statusCode}). Using Fallback.");
        return _getFallbackLessons(languageCode);
      }

      final List<dynamic> data = json.decode(response.body);
      
      if (data.isEmpty) return _getFallbackLessons(languageCode);

      return data.map((json) {
        final content = json['content'] as String;
        return LessonModel(
          id: json['id'],
          userId: json['userId'],
          title: json['title'],
          language: json['language'],
          content: content,
          // Split content into sentences for the Reader
          sentences: _splitIntoSentences(content),
          createdAt: DateTime.now(), 
          imageUrl: json['imageUrl'],
          type: json['type'],
          difficulty: json['difficulty'],
          videoUrl: json['videoUrl'],
          isFavorite: false,
        );
      }).toList();

    } catch (e) {
      print("❌ Feed Error: $e");
      return _getFallbackLessons(languageCode);
    }
  }

  List<String> _splitIntoSentences(String text) {
    return text.split(RegExp(r'[.!?]+')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  }

  // Keep fallback just in case the internet is off
  List<LessonModel> _getFallbackLessons(String lang) {
    return [
      LessonModel(
        id: 'yt_fallback_1',
        userId: 'system',
        title: '${lang.toUpperCase()} Demo (Offline)',
        language: lang,
        content: "Could not fetch data from GitHub.",
        sentences: ["Could not fetch data from GitHub."],
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