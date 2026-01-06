import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:linguaflow/models/speak/speak_models.dart';
import 'package:linguaflow/services/speak/speak_service.dart';

import 'tutor_event.dart';
import 'tutor_state.dart';

class TutorBloc extends Bloc<TutorEvent, TutorState> {
  final SpeakService _speakService = SpeakService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  TutorBloc() : super(const TutorState()) {
    on<LoadTutors>(_onLoadTutors);
    on<FilterTutors>(_onFilterTutors);
    on<ClearTutorFilters>(_onClearTutorFilters);
    on<CreateTutorProfileEvent>(_onCreateTutorProfile);
    on<DeleteTutorProfileEvent>(_onDeleteTutorProfile);
    on<ToggleFavoriteTutor>(_onToggleFavoriteTutor);
    on<ReportTutorEvent>(_onReportTutor);
  }
  Future<void> _onToggleFavoriteTutor(
    ToggleFavoriteTutor event,
    Emitter<TutorState> emit,
  ) async {
    try {
      await _speakService.toggleFavorite(event.tutorId);
      // Ideally, you should also reload the AuthUser to update the UI immediately
      // or trigger an event in AuthBloc to refresh user data.
    } catch (e) {
      print("Error toggling favorite: $e");
    }
  }

  // IMPLEMENT REPORT
  Future<void> _onReportTutor(
    ReportTutorEvent event,
    Emitter<TutorState> emit,
  ) async {
    try {
      await _speakService.reportTutor(event.tutorId, event.reason);
    } catch (e) {
      print("Error reporting tutor: $e");
    }
  }

  // =========================================================
  // 1. LOADING
  // =========================================================
  Future<void> _onLoadTutors(LoadTutors event, Emitter<TutorState> emit) async {
    // Only show loading indicator if list is empty or explicitly refreshing
    if (state.allTutors.isEmpty || event.isRefresh) {
      emit(state.copyWith(status: TutorStatus.loading));
    }

    try {
      final tutors = await _speakService.getTutors();
      // Apply filters immediately after loading
      _applyFilters(emit, allTutors: tutors);
    } catch (e) {
      emit(state.copyWith(status: TutorStatus.failure));
    }
  }

  // =========================================================
  // 2. FILTERING
  // =========================================================
  void _onFilterTutors(FilterTutors event, Emitter<TutorState> emit) {
    final updatedFilters = Map<String, String>.from(state.filters);

    if (event.category != null) {
      if (event.query != null) {
        updatedFilters[event.category!] = event.query!;
      } else {
        updatedFilters.remove(event.category);
      }
    }

    _applyFilters(
      emit,
      filters: updatedFilters,
      query: event.category == null ? event.query : state.searchQuery,
    );
  }

  void _onClearTutorFilters(ClearTutorFilters event, Emitter<TutorState> emit) {
    emit(state.copyWith(resetFilters: true));
    _applyFilters(emit, filters: {}, query: "");
  }

  /// Centralized filter logic.
  /// Updates [filteredTutors] based on [allTutors], [filters], and [query].
  void _applyFilters(
    Emitter<TutorState> emit, {
    List<Tutor>? allTutors,
    Map<String, String>? filters,
    String? query,
  }) {
    final listToFilter = allTutors ?? state.allTutors;
    final activeFilters = filters ?? state.filters;
    final activeQuery = (query ?? state.searchQuery).toLowerCase();
    final currentUser = _auth.currentUser;

    final filteredList = listToFilter.where((tutor) {
      // Rule: Always show the current user's own profile, regardless of filters
      if (currentUser != null && tutor.userId == currentUser.uid) return true;

      // 1. Search Query
      if (activeQuery.isNotEmpty) {
        if (!tutor.name.toLowerCase().contains(activeQuery)) return false;
      }

      // 2. Category Filters
      if (activeFilters.containsKey('Language Level')) {
        if (tutor.level != activeFilters['Language Level']) return false;
      }
      if (activeFilters.containsKey('Specialty')) {
        if (!tutor.specialties.contains(activeFilters['Specialty']))
          return false;
      }

      return true;
    }).toList();

    emit(
      state.copyWith(
        status: TutorStatus.success,
        allTutors: listToFilter,
        filteredTutors: filteredList,
        filters: activeFilters,
        searchQuery: query,
      ),
    );
  }

  // =========================================================
  // 3. CRUD (CREATE / DELETE) - WITH OPTIMISTIC UPDATES
  // =========================================================
  // =========================================================
  // 3. CRUD (CREATE) - FIXED WITH OPTIMISTIC UPDATE
  // =========================================================
  Future<void> _onCreateTutorProfile(
    CreateTutorProfileEvent event,
    Emitter<TutorState> emit,
  ) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // 1. Construct the new Tutor Model locally
    // We populate this with the data from the form immediately.
    final newTutor = Tutor(
      id: user.uid,
      userId: user.uid,
      name: event.name,
      imageUrl: event.imageUrl,
      description: event.description,
      countryOfBirth: event.countryOfBirth,
      isNative: event.isNative,
      language: event.language,
      level: event.level,
      specialties: event.specialties,
      otherLanguages: event.otherLanguages,
      pricePerHour: event.pricePerHour,
      
      // New robust fields
      availability: event.availability, // List<DaySchedule>
      lessons: event.lessons,           // List<TutorLesson>
      
      // Defaults for fields not in the create form
      currency: 'USD',
      socialLinks: const {},
      introVideoUrl: null,
      videoThumbnailUrl: null,
      metadata: event.metadata,
      createdAt: DateTime.now(),
      lastUpdatedAt: DateTime.now(),
      isOnline: true, // Make them appear online immediately
      rating: 5.0,    // Default rating so they aren't hidden by filters
      reviews: 0,
      isVerified: false,
      isSuperTutor: false,
      profileCompletion: 1.0,
    );

    // 2. OPTIMISTIC UPDATE: Update the UI List IMMEDIATELY
    // We take the current list, copy it, and put the new tutor at the very top.
    final updatedList = List<Tutor>.from(state.allTutors)..insert(0, newTutor);
    
    // We call _applyFilters to update 'filteredTutors' and emit the new state
    // This makes the card appear on screen in milliseconds.
    _applyFilters(emit, allTutors: updatedList);

    try {
      // 3. Send to Server (Background Operation)
      await _speakService.createTutorProfile(newTutor);
      
      // CRITICAL: Do NOT call add(LoadTutors()) here.
      // Calling LoadTutors right now might fetch the OLD list from Firestore 
      // before the database has finished indexing the new item.
      // Since we already updated the UI in step 2, we are done.
      
    } catch (e) {
      print("Error creating profile: $e");
      
      // 4. ROLLBACK ON FAILURE
      // If the internet request fails, we must remove the fake item from the list
      // so the user doesn't think it succeeded.
      final revertedList = state.allTutors.where((t) => t.id != newTutor.id).toList();
      _applyFilters(emit, allTutors: revertedList);
      
      // Optionally trigger a failure status to show a SnackBar
      // emit(state.copyWith(status: TutorStatus.failure));
    }
  }

  Future<void> _onDeleteTutorProfile(
    DeleteTutorProfileEvent event,
    Emitter<TutorState> emit,
  ) async {
    // 1. OPTIMISTIC UPDATE: Remove from Local State Immediately
    final updatedList = state.allTutors
        .where((t) => t.id != event.tutorId)
        .toList();
    _applyFilters(emit, allTutors: updatedList);

    try {
      // 2. Send to Server
      await _speakService.deleteTutorProfile(event.tutorId);
    } catch (e) {
      // 3. ROLLBACK (or Reload) ON FAILURE
      // Simplest way to restore state is to fetch from server again
      add(const LoadTutors(isRefresh: true));
    }
  }
}
