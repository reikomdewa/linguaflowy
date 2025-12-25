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
  void _applyFilters(Emitter<TutorState> emit, {
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
        if (!tutor.specialties.contains(activeFilters['Specialty'])) return false;
      }

      return true;
    }).toList();

    emit(state.copyWith(
      status: TutorStatus.success,
      allTutors: listToFilter,
      filteredTutors: filteredList,
      filters: activeFilters,
      searchQuery: query,
    ));
  }

  // =========================================================
  // 3. CRUD (CREATE / DELETE) - WITH OPTIMISTIC UPDATES
  // =========================================================
  Future<void> _onCreateTutorProfile(CreateTutorProfileEvent event, Emitter<TutorState> emit) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // 1. Construct the new Model
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
      
      // New fields from your updated model
      availability: event.availability,
      lessons: event.lessons,
      currency: 'USD',
      socialLinks: const {},
      introVideoUrl: null,
      videoThumbnailUrl: null,
      
      metadata: event.metadata,
      createdAt: DateTime.now(),
      lastUpdatedAt: DateTime.now(),
      isOnline: true,
      rating: 5.0,
      reviews: 0,
      isVerified: false,
      isSuperTutor: false,
      profileCompletion: 0.8,
    );

    // 2. OPTIMISTIC UPDATE: Update Local State Immediately
    // Create a new list with the new tutor added to the top
    final updatedList = List<Tutor>.from(state.allTutors)..insert(0, newTutor);
    
    // Emit state immediately so UI shows the card
    _applyFilters(emit, allTutors: updatedList);

    try {
      // 3. Send to Server (Background)
      await _speakService.createTutorProfile(newTutor);
      // Success! UI is already updated, no need to do anything else.
    } catch (e) {
      // 4. ROLLBACK ON FAILURE
      // If server fails, remove the item from the list
      final revertedList = state.allTutors.where((t) => t.id != newTutor.id).toList();
      _applyFilters(emit, allTutors: revertedList);
      
      emit(state.copyWith(status: TutorStatus.failure));
      // You might want to trigger a snackbar here in the UI via a listener
    }
  }

  Future<void> _onDeleteTutorProfile(DeleteTutorProfileEvent event, Emitter<TutorState> emit) async {
    // 1. OPTIMISTIC UPDATE: Remove from Local State Immediately
    final updatedList = state.allTutors.where((t) => t.id != event.tutorId).toList();
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

  // =========================================================
  // 4. FAVORITES
  // =========================================================
  Future<void> _onToggleFavoriteTutor(ToggleFavoriteTutor event, Emitter<TutorState> emit) async {
    // Logic depends on where favorites are stored (User object vs Local Storage).
    // Typically delegated to the service:
    // await _speakService.toggleFavorite(event.tutorId);
  }
}