import 'package:equatable/equatable.dart';
import 'package:linguaflow/models/lesson_model.dart';

abstract class LessonEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LessonLoadRequested extends LessonEvent {
  final String userId;
  final String languageCode;
  
  LessonLoadRequested(this.userId, this.languageCode);

  @override
  List<Object?> get props => [userId, languageCode];
}

// --- NEW: Event to trigger infinite scroll ---
class LoadMoreLessons extends LessonEvent {} 
// ---------------------------------------------

class LessonCreateRequested extends LessonEvent {
  final LessonModel lesson;
  
  LessonCreateRequested(this.lesson);

  @override
  List<Object?> get props => [lesson];
}

class LessonUpdateRequested extends LessonEvent {
  final LessonModel lesson;
  LessonUpdateRequested(this.lesson);

  @override
  List<Object?> get props => [lesson];
}

class LessonDeleteRequested extends LessonEvent {
  final String lessonId;
  
  LessonDeleteRequested(this.lessonId);

  @override
  List<Object?> get props => [lessonId];
}

class LessonGenerateRequested extends LessonEvent {
  final String userId;
  final String topic;
  final String level;
  final String targetLanguage;

   LessonGenerateRequested({
    required this.userId,
    required this.topic,
    required this.level,
    required this.targetLanguage,
  });

  @override
  List<Object?> get props => [userId, topic, level, targetLanguage];
}