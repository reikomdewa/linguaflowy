import 'dart:convert';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:linguaflow/models/quiz_model.dart';

enum QuizPromptType { placementTest, dailyPractice, topicSpecific }

class QuizService {
  
  static final QuizService _instance = QuizService._internal();
  factory QuizService() => _instance;
  QuizService._internal();

  /// Main method to generate quiz questions
  Future<List<QuizQuestion>> generateQuiz({
    required String userId,
    required String targetLanguage,
    required String nativeLanguage,
    required QuizPromptType type,
    String? topic,
  }) async {
    
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) throw Exception("GEMINI_API_KEY missing");
    
    Gemini.init(apiKey: apiKey);

    // 1. FETCH CONTEXT DATA (Parallel fetch for speed)
    final results = await Future.wait([
      _fetchUserVocabulary(userId, targetLanguage), // Words to INCLUDE
      _fetchQuizHistory(userId, targetLanguage),    // Sentences to AVOID
    ]);

    final List<String> userVocabulary = results[0];
    final List<String> quizHistory = results[1];

    // 2. Generate Prompt
    final String prompt = _getPromptTemplate(
      type, 
      targetLanguage, 
      nativeLanguage, 
      topic,
      userVocabulary,
      quizHistory // Pass history here
    );

    try {
      final value = await Gemini.instance.prompt(parts: [Part.text(prompt)]);
      String? responseText = value?.output;

      if (responseText == null) throw Exception("Empty response from Gemini");

      responseText = responseText.replaceAll('```json', '').replaceAll('```', '').trim();
      
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

      // 3. SAVE NEW HISTORY (Fire and forget - don't wait for it to finish)
      _saveQuizHistory(userId, targetLanguage, questions);

      return questions;

    } catch (e) {
      print("Quiz Service Error: $e");
      throw Exception("Failed to generate quiz: $e");
    }
  }

  // --- FIRESTORE HELPERS ---

  /// 1. Fetch Vocabulary (Words to Include)
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
    } catch (e) {
      return [];
    }
  }

  /// 2. Fetch Quiz History (Sentences to Avoid)
  Future<List<String>> _fetchQuizHistory(String userId, String targetLang) async {
    try {
      // We assume you have a collection 'quiz_history'
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('quiz_history')
          .where('language', isEqualTo: targetLang)
          .orderBy('createdAt', descending: true) // Get most recent
          .limit(50) // Limit to last 50 sentences to keep prompt small
          .get();

      return snapshot.docs.map((doc) => doc['targetSentence'] as String).toList();
    } catch (e) {
      print("Error fetching history: $e");
      return [];
    }
  }

  /// 3. Save New Questions to History
  Future<void> _saveQuizHistory(String userId, String targetLang, List<QuizQuestion> questions) async {
    final batch = FirebaseFirestore.instance.batch();
    final collectionRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('quiz_history');

    for (var q in questions) {
      // Create a doc ID based on time + hash to avoid collisions
      final docRef = collectionRef.doc(); 
      batch.set(docRef, {
        'targetSentence': q.targetSentence,
        'language': targetLang,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    try {
      await batch.commit();
      print("Quiz history saved.");
    } catch (e) {
      print("Error saving quiz history: $e");
    }
  }

  // --- PROMPT TEMPLATE ---

String _getPromptTemplate(
    QuizPromptType type, 
    String targetLang, 
    String nativeLang, 
    String? topic,
    List<String> vocabulary,
    List<String> history,
  ) {
    
    // 1. Build Vocab Context
    String vocabContext = "";
    if (vocabulary.isNotEmpty) {
      vocabContext = """
      INCLUSION INSTRUCTIONS:
      The user is learning these words. PRIORITIZE using them in your sentences:
      ${vocabulary.join(", ")}
      """;
    }

    // 2. Build History Context
    String historyContext = "";
    if (history.isNotEmpty) {
      historyContext = """
      EXCLUSION INSTRUCTIONS:
      The user has recently seen the sentences below. 
      Please RARELY generate these exact sentences. You may reuse the vocabulary, 
      but try to change the grammar, context, or structure to keep it fresh.
      RECENT SENTENCES:
      ${history.join(" | ")}
      """;
    }

    // 3. Specific Instructions
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

    // 4. THE RETURNED PROMPT (With Restored Rules)
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