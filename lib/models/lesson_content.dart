class LessonAIContent {
  final List<LessonVocabulary> vocabulary;
  final LessonGrammar grammar;

  LessonAIContent({required this.vocabulary, required this.grammar});

  factory LessonAIContent.fromJson(Map<String, dynamic> json) {
    return LessonAIContent(
      vocabulary: (json['vocabulary'] as List?)
          ?.map((e) => LessonVocabulary.fromJson(e))
          .toList() ?? [],
      grammar: LessonGrammar.fromJson(json['grammar'] ?? {}),
    );
  }
}

class LessonVocabulary {
  final String word;
  final String translation;
  final String contextSentence;
  final String contextTranslation; // <--- NEW FIELD

  LessonVocabulary({
    required this.word,
    required this.translation,
    required this.contextSentence,
    required this.contextTranslation,
  });

  factory LessonVocabulary.fromJson(Map<String, dynamic> json) {
    return LessonVocabulary(
      word: json['word']?.toString() ?? '',
      translation: json['translation']?.toString() ?? '',
      contextSentence: json['contextSentence']?.toString() ?? '',
      contextTranslation: json['contextTranslation']?.toString() ?? '', // <--- Map it
    );
  }
}

class LessonGrammar {
  final String title;
  final String explanation;
  final String example;

  LessonGrammar({
    required this.title,
    required this.explanation,
    required this.example,
  });

  factory LessonGrammar.fromJson(Map<String, dynamic> json) {
    return LessonGrammar(
      title: json['title']?.toString() ?? 'Grammar Point',
      explanation: json['explanation']?.toString() ?? 'No explanation available.',
      example: json['example']?.toString() ?? '',
    );
  }
}