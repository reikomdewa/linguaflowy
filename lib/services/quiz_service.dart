import 'dart:convert';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:linguaflow/models/quiz_model.dart';

enum QuizPromptType { placementTest, dailyPractice, topicSpecific }

class QuizService {
  
  // Singleton pattern (optional, but good for services)
  static final QuizService _instance = QuizService._internal();
  factory QuizService() => _instance;
  QuizService._internal();

  /// Main method to generate quiz questions
  Future<List<QuizQuestion>> generateQuiz({
    required String targetLanguage,
    required String nativeLanguage,
    required QuizPromptType type,
    String? topic, // Optional: for topic specific quizzes
  }) async {
    
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception("GEMINI_API_KEY missing in .env file");
    }
    
    // Initialize Gemini if not already done (safe to call multiple times internally)
    Gemini.init(apiKey: apiKey);

    // 1. Select the correct Prompt Template
    final String prompt = _getPromptTemplate(type, targetLanguage, nativeLanguage, topic);

    try {
      final value = await Gemini.instance.prompt(parts: [Part.text(prompt)]);
      String? responseText = value?.output;

      if (responseText == null) throw Exception("Empty response from Gemini");

      // 2. Clean JSON (Remove markdown code blocks)
      responseText = responseText.replaceAll('```json', '').replaceAll('```', '').trim();
      
      final List<dynamic> data = jsonDecode(responseText);

      return data.map((item) {
        return QuizQuestion(
          id: item['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
          type: item['type'] ?? 'target_to_native',
          targetSentence: item['targetSentence'],
          correctAnswer: item['correctAnswer'],
          options: List<String>.from(item['options']),
        );
      }).toList();

    } catch (e) {
      print("Quiz Service Error: $e");
      throw Exception("Failed to generate quiz: $e");
    }
  }

  /// Helper to build the specific prompt string
  String _getPromptTemplate(QuizPromptType type, String targetLang, String nativeLang, String? topic) {
    
    String instruction = "";

    switch (type) {
      case QuizPromptType.placementTest:
        instruction = """
          Generate 10 placement test sentences ranging from A1 (Beginner) to C1 (Advanced).
          The difficulty MUST increase progressively.
          Questions 1-3: A1/A2 (Simple sentences)
          Questions 4-7: B1/B2 (Complex grammar, past/future tense)
          Questions 8-10: C1 (Nuanced vocabulary, idioms)
        """;
        break;
      
      case QuizPromptType.dailyPractice:
        instruction = """
          Generate 10 beginner-level (A1/A2) sentences for daily practice.
          Mix simple greetings, food, and travel phrases.
        """;
        break;

      case QuizPromptType.topicSpecific:
        instruction = """
          Generate 10 sentences specifically about the topic: "${topic ?? 'General'}".
          Level: Intermediate (B1).
        """;
        break;
    }

    return """
      $instruction
      
      Language A (Target): $targetLang
      Language B (Native): $nativeLang
      
      Return ONLY valid JSON. Do not include markdown formatting.
      
      Generate a MIX of "target_to_native" and "native_to_target".
      
      Format:
      [
        {
          "id": "1",
          "type": "target_to_native",
          "targetSentence": "Sentence in Source Language",
          "correctAnswer": "Translation in Result Language",
          "options": ["word1", "word2", "word3"] 
        }
      ]
      
      Rules:
      1. 'options' must contain words from 'correctAnswer' scattered + 3-4 distractors.
      2. For "native_to_target", 'options' are in $targetLang.
      3. For "target_to_native", 'options' are in $nativeLang.
    """;
  }
}