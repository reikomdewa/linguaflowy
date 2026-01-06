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
  // --- NEW: Pagination Flags ---
  final bool hasReachedMax; // True if no more data in Firestore
  final bool isLoadingMore; // True if currently fetching next page

   LessonLoaded(
    this.lessons, {
    this.hasReachedMax = false,
    this.isLoadingMore = false,
  });

  // --- NEW: CopyWith Method ---
  // Essential for updating flags without losing the list data
  LessonLoaded copyWith({
    List<LessonModel>? lessons,
    bool? hasReachedMax,
    bool? isLoadingMore,
  }) {
    return LessonLoaded(
      lessons ?? this.lessons,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object?> get props => [lessons, hasReachedMax, isLoadingMore];
}

class LessonError extends LessonState {
  final String message;
  
  LessonError(this.message);

  @override
  List<Object?> get props => [message];
}

class LessonGenerationSuccess extends LessonState {
  final LessonModel lesson;
  LessonGenerationSuccess(this.lesson);

  @override
  List<Object> get props => [lesson];
}