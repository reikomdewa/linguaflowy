// File: lib/blocs/lesson/lesson_state.dart

import 'package:equatable/equatable.dart';
import 'package:linguaflow/models/lesson_model.dart';

abstract class LessonState extends Equatable {
  @override
  List<Object?> get props => [];
}

class LessonInitial extends LessonState {}

class LessonLoading extends LessonState {}

class LessonLoaded extends LessonState {
  final List<LessonModel> lessons;
  
  LessonLoaded(this.lessons);

  @override
  List<Object?> get props => [lessons];
}

class LessonError extends LessonState {
  final String message;
  
  LessonError(this.message);

  @override
  List<Object?> get props => [message];
}