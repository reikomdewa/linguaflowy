import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:linguaflow/models/speak/tutor.dart';
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
  }

  // =========================================================
  // 1. LOADING
  // =========================================================
  Future<void> _onLoadTutors(LoadTutors event, Emitter<TutorState> emit) async {
    if (state.allTutors.isEmpty || event.isRefresh) {
      emit(state.copyWith(status: TutorStatus.loading));
    }

    try {
      final tutors = await _speakService.getTutors();
      // Initially, filtered list = all tutors
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

  void _applyFilters(Emitter<TutorState> emit, {
    List<Tutor>? allTutors,
    Map<String, String>? filters,
    String? query,
  }) {
    final _all = allTutors ?? state.allTutors;
    final _filters = filters ?? state.filters;
    final _query = (query ?? state.searchQuery).toLowerCase();
    final currentUser = _auth.currentUser;

    final _filtered = _all.where((tutor) {
      // Always show own profile
      if (currentUser != null && tutor.userId == currentUser.uid) return true;

      // 1. Search Query
      if (_query.isNotEmpty) {
        if (!tutor.name.toLowerCase().contains(_query)) return false;
      }

      // 2. Category Filters
      if (_filters.containsKey('Language Level')) {
        if (tutor.level != _filters['Language Level']) return false;
      }
      if (_filters.containsKey('Specialty')) {
        if (!tutor.specialties.contains(_filters['Specialty'])) return false;
      }

      return true;
    }).toList();

    emit(state.copyWith(
      status: TutorStatus.success,
      allTutors: _all,
      filteredTutors: _filtered,
      filters: _filters,
      searchQuery: query,
    ));
  }

  // =========================================================
  // 3. CRUD
  // =========================================================
  Future<void> _onCreateTutorProfile(CreateTutorProfileEvent event, Emitter<TutorState> emit) async {
    final user = _auth.currentUser;
    if (user == null) return;

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
      availability: event.availability,
      lessons: event.lessons,
      metadata: event.metadata,
      createdAt: DateTime.now(),
      lastUpdatedAt: DateTime.now(),
      isOnline: true,
      rating: 5.0,
      reviews: 0,
    );

    await _speakService.createTutorProfile(newTutor);
    
    // Refresh the list after creation
    add(const LoadTutors(isRefresh: true));
  }

  Future<void> _onDeleteTutorProfile(DeleteTutorProfileEvent event, Emitter<TutorState> emit) async {
    final updatedList = state.allTutors.where((t) => t.id != event.tutorId).toList();
    _applyFilters(emit, allTutors: updatedList);

    await _speakService.deleteTutorProfile(event.tutorId);
  }
}