import 'dart:convert';
import 'dart:async';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:linguaflow/models/quiz_model.dart';

enum QuizPromptType { placementTest, dailyPractice, topicSpecific }

class QuizService {
  
  static final QuizService _instance = QuizService._internal();
  factory QuizService() => _instance;
  
  QuizService._internal();

  // --- MODEL CONFIGURATION ---
  // Based on your logs, 1.5 is deprecated. We use 2.5.
  static const String _primaryModel = 'gemini-2.5-flash';
  static const String _fallbackModel = 'gemini-2.5-pro';

  Future<List<QuizQuestion>> generateQuiz({
    required String userId,
    required String targetLanguage,
    required String nativeLanguage,
    required QuizPromptType type,
    String? topic,
  }) async {
    
    // 1. Throttle
    await Future.delayed(const Duration(milliseconds: 500));

    // 2. Context Data
    final results = await Future.wait([
      _fetchUserVocabulary(userId, targetLanguage),
      _fetchQuizHistory(userId, targetLanguage),
    ]);

    final List<String> userVocabulary = results[0];
    final List<String> quizHistory = results[1];

    final String prompt = _getPromptTemplate(
      type, 
      targetLanguage, 
      nativeLanguage, 
      topic,
      userVocabulary,
      quizHistory
    );

    try {
      // 3. Generate with Retry
      String? responseText = await _generateWithRetry(prompt);

      if (responseText == null) throw Exception("Empty response from AI");

      responseText = responseText
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      
      final List<dynamic> data = jsonDecode(responseText);

      List<QuizQuestion> questions = data.map((item) {
        return QuizQuestion(
          id: item['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
          type: item['type'] ?? 'target_to_native',
          targetSentence: item['targetSentence'],
          correctAnswer: item['correctAnswer'],
          options: List<String>.from(item['options']),
        );
      }).toList();

      _saveQuizHistory(userId, targetLanguage, questions);

      return questions;

    } catch (e) {
      print("Quiz Service Error: $e");
      if (e.toString().contains("429") || e.toString().contains("quota") || e.toString().contains("exhausted")) {
        throw Exception("Server is busy (Rate Limit). Please wait a moment.");
      }
      // Pass through specific model errors if they occur
      throw Exception("Failed to generate quiz: $e");
    }
  }

  // --- RETRY HELPER ---
  Future<String?> _generateWithRetry(String promptText) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception("GEMINI_API_KEY is missing");
    }

    int attempts = 0;
    
    // We will try the primary model first, then fallback if needed
    String currentModelName = _primaryModel;

    while (attempts < 3) {
      try {
        final model = GenerativeModel(
          model: currentModelName, 
          apiKey: apiKey,
        );

        final content = [Content.text(promptText)];
        final response = await model.generateContent(content);
        return response.text;

      } catch (e) {
        final err = e.toString();
        print("⚠️ Attempt ${attempts + 1} failed with $currentModelName: $err");

        // 1. Handle Rate Limits (429)
        if (err.contains("429") || err.contains("quota") || err.contains("exhausted")) {
          attempts++;
          int waitTime = attempts * 2;
          print("⏳ Rate limit. Waiting $waitTime seconds...");
          await Future.delayed(Duration(seconds: waitTime));
        }
        // 2. Handle "Not Found" / Deprecated Model
        else if (err.contains("not found") || err.contains("404") || err.contains("deprecated")) {
           if (currentModelName == _primaryModel) {
             print("🔄 Model $_primaryModel not found. Switching to $_fallbackModel...");
             currentModelName = _fallbackModel;
             // Don't increment attempts, just switch model immediately and try again
             continue; 
           } else {
             // If fallback also fails, we are stuck.
             print("❌ All models failed.");
             rethrow;
           }
        }
        // 3. Other errors
        else {
          rethrow;
        }
      }
    }
    throw Exception("Failed after 3 attempts.");
  }

  // --- FIRESTORE HELPERS ---
  Future<List<String>> _fetchUserVocabulary(String userId, String targetLang) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('vocabulary')
          .where('language', isEqualTo: targetLang)
          .where('status', whereIn: [1, 2, 3, 4]) 
          .orderBy('lastReviewed', descending: true)
          .limit(30) 
          .get();
      return snapshot.docs.map((doc) => doc['word'] as String).toList();
    } catch (e) { return []; }
  }

  Future<List<String>> _fetchQuizHistory(String userId, String targetLang) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('quiz_history')
          .where('language', isEqualTo: targetLang)
          .orderBy('createdAt', descending: true) 
          .limit(50) 
          .get();
      return snapshot.docs.map((doc) => doc['targetSentence'] as String).toList();
    } catch (e) { return []; }
  }

  Future<void> _saveQuizHistory(String userId, String targetLang, List<QuizQuestion> questions) async {
    final batch = FirebaseFirestore.instance.batch();
    final collectionRef = FirebaseFirestore.instance.collection('users').doc(userId).collection('quiz_history');
    for (var q in questions) {
      final docRef = collectionRef.doc(); 
      batch.set(docRef, {
        'targetSentence': q.targetSentence,
        'language': targetLang,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    try { await batch.commit(); } catch (e) { /* ignore */ }
  }

  String _getPromptTemplate(
    QuizPromptType type, 
    String targetLang, 
    String nativeLang, 
    String? topic,
    List<String> vocabulary,
    List<String> history,
  ) {
    String vocabContext = vocabulary.isNotEmpty ? 
      """
      INCLUSION INSTRUCTIONS:
      The user is learning these words. PRIORITIZE using them in your sentences:
      ${vocabulary.join(", ")}
      """ : "";

    String historyContext = history.isNotEmpty ? 
      """
      EXCLUSION INSTRUCTIONS:
      The user has recently seen the sentences below. 
      Please RARELY generate these exact sentences. You may reuse the vocabulary, 
      but try to change the grammar, context, or structure to keep it fresh.
      RECENT SENTENCES:
      ${history.join(" | ")}
      """ : "";

    String specificInstruction = "";
    switch (type) {
      case QuizPromptType.placementTest:
        specificInstruction = "Generate 10 placement test sentences ranging from A1 (Beginner) to C1 (Advanced). Difficulty MUST increase.";
        break;
      case QuizPromptType.dailyPractice:
        specificInstruction = "Generate 10 beginner/intermediate sentences for daily practice. Mix simple greetings, food, and travel phrases.";
        break;
      case QuizPromptType.topicSpecific:
        specificInstruction = "Generate 10 sentences specifically about the topic: '${topic ?? 'General'}'. Level: Intermediate (B1).";
        break;
    }

    return """
      Task: Generate a language quiz.
      Language A (Target): $targetLang
      Language B (Native): $nativeLang
      
      $specificInstruction
      
      $vocabContext
      
      $historyContext
      
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
      
      *** CRITICAL RULES FOR 'options': ***
      1. The 'options' array MUST NOT BE EMPTY.
      2. 'options' must contain the individual words from 'correctAnswer' shuffled.
      3. Add 3-4 random 'distractor' words (wrong words) to the 'options' array.
      4. For "native_to_target" (Translate $nativeLang -> $targetLang): 'options' must be in $targetLang.
      5. For "target_to_native" (Translate $targetLang -> $nativeLang): 'options' must be in $nativeLang.
    """;
  }
}