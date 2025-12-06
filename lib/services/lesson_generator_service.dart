import 'dart:convert';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:linguaflow/models/lesson_content.dart';

class LessonGeneratorService {
  // No constructor needed. We rely on the global Gemini.instance

  Future<LessonAIContent> generateLessonPlan({
    required String transcriptText,
    required String targetLang,
    required String nativeLang,
  }) async {
    // 1. Safety Truncate: Gemini has token limits.
    // 5000 chars is usually enough to get the context without hitting limits.
    final safeText = transcriptText.length > 5000
        ? transcriptText.substring(0, 5000)
        : transcriptText;

    final prompt =
        """
      You are a language teacher creating a lesson plan.
      Target Language: $targetLang
      Student's Native Language: $nativeLang
      
      SOURCE TEXT (Video Transcript):
      "$safeText"
      
      TASK:
      1. Extract 5 key vocabulary words from the text.
      2. Identify 3 to 5 distinct grammar rules or patterns used in the text.
      3. For each grammar rule, provide a short title, a concise explanation (max 2 sentences), and an example from the text (or similar).
      
      Return JSON format ONLY:
      {
        "vocabulary": [
          { 
            "word": "Word in $targetLang", 
            "translation": "Meaning in $nativeLang", 
            "contextSentence": "Sentence in $targetLang",
            "contextTranslation": "Sentence meaning in $nativeLang" 
          }
        ],
        "grammar": [
          {
            "title": "Grammar Point 1",
            "explanation": "Explanation in $nativeLang.",
            "example": "Example in $targetLang"
          },
           {
            "title": "Grammar Point 2",
            "explanation": "Explanation in $nativeLang.",
            "example": "Example in $targetLang"
          }
        ]
      }
    """;

    try {
      // 2. Call Gemini
      final value = await Gemini.instance.prompt(parts: [Part.text(prompt)]);
      String? responseText = value?.output;

      if (responseText == null) throw Exception("Empty response from AI");

      // 3. Clean Markdown (Your Regex Pattern)
      // Removes ```json at start and ``` at end, and trims whitespace
      responseText = responseText
          .replaceAll(RegExp(r'^```json|```$'), '')
          .trim();
      // Sometimes Gemini leaves just ``` without json
      responseText = responseText.replaceAll('```', '').trim();

      // 4. Decode
      final Map<String, dynamic> data = jsonDecode(responseText);

      // 5. Map to Model
      return LessonAIContent.fromJson(data);
    } catch (e) {
      print("Lesson Plan Generation Error: $e");
      // Return fallback content so the app doesn't crash
      return _getFallbackContent();
    }
  }

  LessonAIContent _getFallbackContent() {
    return LessonAIContent(
      vocabulary: [
        LessonVocabulary(
          word: "Error",
          translation: "Error",
          contextSentence: "Could not generate lesson plan.",
          contextTranslation: "no translation available.",
        ),
      ],
      grammar: [
        LessonGrammar(
          title: "Connection Issue",
          explanation: "We couldn't reach the AI teacher right now.",
          example: "Please try again later.",
        ),
      ],
    );
  }
}
