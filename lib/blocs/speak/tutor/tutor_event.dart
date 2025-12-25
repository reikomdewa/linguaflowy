import 'package:equatable/equatable.dart';
import 'package:linguaflow/models/speak/speak_models.dart';

abstract class TutorEvent extends Equatable {
  const TutorEvent();
  @override
  List<Object?> get props => [];
}

// ==========================================
// DATA & FILTERING
// ==========================================

class LoadTutors extends TutorEvent {
  final bool isRefresh;
  const LoadTutors({this.isRefresh = false});
}

class FilterTutors extends TutorEvent {
  final String? query;
  final String? category; // 'Specialty', 'Language Level'
  const FilterTutors(this.query, {this.category});
  @override
  List<Object?> get props => [query, category];
}

class ClearTutorFilters extends TutorEvent {}

// ==========================================
// PROFILE MANAGEMENT
// ==========================================

class CreateTutorProfileEvent extends TutorEvent {
  final String name;
  final String description;
  final String imageUrl;
  final String countryOfBirth;
  final bool isNative;
  final String language;
  final String level;
  final double pricePerHour;
  final List<String> specialties;
  final List<String> otherLanguages;
  final Map<String, String> availability;
  final List<TutorLesson> lessons;
  final Map<String, dynamic> metadata;

  const CreateTutorProfileEvent({
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.countryOfBirth,
    required this.isNative,
    required this.language,
    required this.level,
    required this.pricePerHour,
    required this.specialties,
    required this.otherLanguages,
    required this.availability,
    required this.lessons,
    this.metadata = const {},
  });

  @override
  List<Object?> get props => [name, language, pricePerHour, isNative];
}

class UpdateTutorProfileEvent extends CreateTutorProfileEvent {
  const UpdateTutorProfileEvent({
    required super.name,
    required super.description,
    required super.imageUrl,
    required super.countryOfBirth,
    required super.isNative,
    required super.language,
    required super.level,
    required super.pricePerHour,
    required super.specialties,
    required super.otherLanguages,
    required super.availability,
    required super.lessons,
    super.metadata,
  });
}

class DeleteTutorProfileEvent extends TutorEvent {
  final String tutorId;
  const DeleteTutorProfileEvent(this.tutorId);
  @override
  List<Object?> get props => [tutorId];
}

// ==========================================
// INTERACTION
// ==========================================

class ToggleFavoriteTutor extends TutorEvent {
  final String tutorId;
  const ToggleFavoriteTutor(this.tutorId);
  @override
  List<Object?> get props => [tutorId];
}

class BookLessonEvent extends TutorEvent {
  final Tutor tutor;
  final TutorLesson lesson;
  final DateTime scheduledTime;

  const BookLessonEvent({
    required this.tutor,
    required this.lesson,
    required this.scheduledTime,
  });

  @override
  List<Object?> get props => [tutor, lesson, scheduledTime];
}