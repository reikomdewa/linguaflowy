// enum QuestionType { translate, listen, fillGap, matching }

// class QuestionModel {
//   final String id;
//   final QuestionType type;
//   final String question; // "The cat eats" or Audio URL
//   final List<String> correctAnswers; // ["El gato come", "El gato está comiendo"]
//   final List<String> options; // ["El", "perro", "gato", "come", "bebe"] (Word Bank)
//   final String? explanation; // "Gato is masculine, so use El"

//   QuestionModel({
//     required this.id,
//     required this.type,
//     required this.question,
//     required this.correctAnswers,
//     required this.options,
//     this.explanation,
//   });

//   // Add fromMap/toMap...
// }

// class QuizLessonModel {
//   final String id;
//   final String title; // "Basics 1"
//   final List<QuestionModel> questions;
  
//   QuizLessonModel({required this.id, required this.title, required this.questions});
// }

// class QuizQuestion {
//   final String id;
//   final String type; // 'target_to_native' or 'native_to_target'
//   final String targetSentence; // The sentence to be translated (The Question)
//   final String correctAnswer;  // The correct translation (The Answer)
//   final List<String> options;  // The word bank choices

//   QuizQuestion({
//     required this.id,
//     required this.type,
//     required this.targetSentence,
//     required this.correctAnswer,
//     required this.options,
//   });
// }

class QuizQuestion {
  final String id;
  final String type; // 'target_to_native' or 'native_to_target'
  final String targetSentence; 
  final String correctAnswer;
  final List<String> options;

  QuizQuestion({
    required this.id,
    required this.type,
    required this.targetSentence,
    required this.correctAnswer,
    required this.options,
  });
}