import 'package:equatable/equatable.dart';
import 'package:linguaflow/models/speak/speak_models.dart';

enum TutorStatus { initial, loading, success, failure }

class TutorState extends Equatable {
  final TutorStatus status;
  final List<Tutor> allTutors;       // The master list of tutors
  final List<Tutor> filteredTutors;  // The list actually displayed in UI after filters
  final Map<String, String> filters;   // Filters applied to tutors
  final String searchQuery;            // Search query for tutors
  final Tutor? selectedTutor;          // For booking or viewing a detailed profile

  const TutorState({
    this.status = TutorStatus.initial,
    this.allTutors = const [],
    this.filteredTutors = const [],
    this.filters = const {},
    this.searchQuery = '',
    this.selectedTutor,
  });

  TutorState copyWith({
    TutorStatus? status,
    List<Tutor>? allTutors,
    List<Tutor>? filteredTutors,
    Map<String, String>? filters,
    String? searchQuery,
    Tutor? selectedTutor,
    bool clearSelectedTutor = false,     // Special flag to clear selected tutor
    bool resetFilters = false,           // Special flag to reset filters
  }) {
    return TutorState(
      status: status ?? this.status,
      allTutors: allTutors ?? this.allTutors,
      filteredTutors: filteredTutors ?? this.filteredTutors,
      filters: resetFilters ? const {} : (filters ?? this.filters),
      searchQuery: resetFilters ? '' : (searchQuery ?? this.searchQuery),
      selectedTutor: clearSelectedTutor ? null : (selectedTutor ?? this.selectedTutor),
    );
  }

  @override
  List<Object?> get props => [
        status,
        allTutors,
        filteredTutors,
        filters,
        searchQuery,
        selectedTutor,
      ];
}