// //File: lib/blocs/lesson/lesson_event.dart**
// import 'package:linguaflow/models/lesson_model.dart';

// abstract class LessonEvent {}

// class LessonLoadRequested extends LessonEvent {
//   final String userId;
//   final String languageCode;
//   LessonLoadRequested(this.userId, this.languageCode);
// }

// class LessonCreateRequested extends LessonEvent {
//   final LessonModel lesson;
//   LessonCreateRequested(this.lesson);
// }

// class LessonDeleteRequested extends LessonEvent {
//   final String lessonId;
//   LessonDeleteRequested(this.lessonId);
// }


// File: lib/blocs/lesson/lesson_event.dart

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

class LessonCreateRequested extends LessonEvent {
  final LessonModel lesson;
  
  LessonCreateRequested(this.lesson);

  @override
  List<Object?> get props => [lesson];
}

class LessonDeleteRequested extends LessonEvent {
  final String lessonId;
  
  LessonDeleteRequested(this.lessonId);

  @override
  List<Object?> get props => [lessonId];
}