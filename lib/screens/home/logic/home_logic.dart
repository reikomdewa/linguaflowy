import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/models/vocabulary_item.dart';

class HomeLogic {
  /// Calculates stats based on the lesson content vs the user's vocabulary map
  static Map<String, int> getLessonStats(
    LessonModel lesson,
    Map<String, VocabularyItem> vocabMap,
  ) {
    String fullText = lesson.content;
    if (lesson.transcript.isNotEmpty) {
      fullText = lesson.transcript.map((e) => e.text).join(" ");
    }

    final List<String> words = fullText.split(RegExp(r'(\s+)'));
    int newWords = 0;
    int knownWords = 0;
    final Set<String> uniqueWords = {};

    for (var word in words) {
      final cleanWord = word.toLowerCase().trim().replaceAll(
            RegExp(r'[^\w\s]'),
            '',
          );
      if (cleanWord.isEmpty) continue;
      if (uniqueWords.contains(cleanWord)) continue;

      uniqueWords.add(cleanWord);
      final vocabItem = vocabMap[cleanWord];

      if (vocabItem == null || vocabItem.status == 0) {
        newWords++;
      } else {
        knownWords++;
      }
    }
    return {'new': newWords, 'known': knownWords};
  }
}