import 'dart:convert';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:uuid/uuid.dart';

class GeminiService {
  
  // No constructor needed. We rely on the global instance initialized in main.dart

  Future<LessonModel> generateLesson({
    required String topic,
    required String level,
    required String targetLanguage,
    required String userId,
  }) async {
    final prompt = """
      You are a language teacher. 
      Target Language Code: $targetLanguage
      Level: $level
      Topic: $topic

      Create a short story lesson.
      1. Write a story (approx 100 words).
      2. Extract 5 key sentences from the story.
      
      Return ONLY valid JSON. No markdown. Structure:
      {
        "title": "Title in $targetLanguage",
        "content": "Story text...",
        "sentences": ["Sentence 1", "Sentence 2", "Sentence 3", "Sentence 4", "Sentence 5"],
        "difficulty": "$level"
      }
    """;

    try {
      // Direct call to the global instance
      final value = await Gemini.instance.prompt(parts: [Part.text(prompt)]);
      String? responseText = value?.output;

      if (responseText == null) throw Exception("Empty response from AI");

      // 1. Clean Markdown (Gemini often wraps JSON in ```json ... ```)
      responseText = responseText.replaceAll(RegExp(r'^```json|```$'), '').trim();
      
      // 2. Decode
      final Map<String, dynamic> data = jsonDecode(responseText);

      // 3. Map to Model (Safe Mode)
      return LessonModel(
        id: const Uuid().v4(),
        userId: userId,
        title: data['title']?.toString() ?? 'AI Lesson',
        language: targetLanguage,
        content: data['content']?.toString() ?? '',
        
        // Safely convert list to Strings
        sentences: (data['sentences'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ?? [],
            
        // FORCE EMPTY TRANSCRIPT to fix the "Null is not subtype of num" crash.
        // AI text generation doesn't reliably create the numeric timecodes your model expects.
        transcript: [], 
        
        createdAt: DateTime.now(),
        difficulty: data['difficulty']?.toString() ?? level,
        type: 'ai_story',
        isFavorite: false,
        progress: 0,
      );
    } catch (e) {
      print("Gemini Parsing Error: $e");
      throw Exception("Failed to generate lesson. Try a different topic.");
    }
  }
}