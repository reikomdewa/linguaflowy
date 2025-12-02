import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:linguaflow/models/lesson_model.dart';

class GitHubLessonService {
  // 🔴 1. PUSH YOUR CODE TO GITHUB FIRST!
  // 🔴 2. REPLACE WITH YOUR USERNAME AND REPO NAME
  static const String _repoOwner = 'reikomdewa';
  static const String _repoName = 'linguaflowy';
  
  // This points to the raw file in your repository
  String get _baseUrl => 'https://raw.githubusercontent.com/$_repoOwner/$_repoName/main/data';

  Future<List<LessonModel>> fetchRecommendedVideos(String languageCode) async {
    try {
      final url = '$_baseUrl/lessons_$languageCode.json';
      
      print("📥 Fetching Feed: $url");
      
      // Cache Busting: Add timestamp so we never get stale data
      final uri = Uri.parse('$url?t=${DateTime.now().millisecondsSinceEpoch}');
      
      final response = await http.get(uri);

      if (response.statusCode == 404) {
        print("⚠️ Feed file not created yet (404). Waiting for GitHub Action.");
        return _getFallbackLessons(languageCode);
      }

      if (response.statusCode != 200) {
        throw Exception("GitHub Error ${response.statusCode}");
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
          // Re-generate sentences client-side to save JSON bandwidth
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
      // Fallback allows you to work while waiting for the first scrape
      return _getFallbackLessons(languageCode);
    }
  }

  List<String> _splitIntoSentences(String text) {
    return text.split(RegExp(r'[.!?]+')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  }

  List<LessonModel> _getFallbackLessons(String lang) {
    return [
      LessonModel(
        id: 'yt_fallback_1',
        userId: 'system',
        title: 'Welcome to your Feed (Demo)',
        language: lang,
        content: "Your GitHub Action is running! Once it finishes, real videos will appear here automatically.",
        sentences: ["Your GitHub Action is running!"],
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