// ==========================================
// VOCABULARY BLOC
// ==========================================
// File: lib/blocs/vocabulary/vocabulary_bloc.dart
import 'package:bloc/bloc.dart';
import 'package:linguaflow/models/vocabulary_item.dart';
import 'package:linguaflow/services/vocabulary_service.dart';

// Events
abstract class VocabularyEvent {}

class VocabularyLoadRequested extends VocabularyEvent {
  final String userId;
  VocabularyLoadRequested(this.userId);
}

class VocabularyAddRequested extends VocabularyEvent {
  final VocabularyItem item;
  VocabularyAddRequested(this.item);
}

class VocabularyUpdateRequested extends VocabularyEvent {
  final VocabularyItem item;
  VocabularyUpdateRequested(this.item);
}

// ✅ NEW: Added Delete Event
class VocabularyDeleteRequested extends VocabularyEvent {
  final String id;
  final String userId;
  VocabularyDeleteRequested({required this.id, required this.userId});
}

// States
abstract class VocabularyState {}

class VocabularyInitial extends VocabularyState {}

class VocabularyLoading extends VocabularyState {}

class VocabularyLoaded extends VocabularyState {
  final List<VocabularyItem> items;
  VocabularyLoaded(this.items);
}

class VocabularyError extends VocabularyState {
  final String message;
  VocabularyError(this.message);
}

// Bloc
class VocabularyBloc extends Bloc<VocabularyEvent, VocabularyState> {
  final VocabularyService vocabularyService;

  VocabularyBloc(this.vocabularyService) : super(VocabularyInitial()) {
    on<VocabularyLoadRequested>(_onVocabularyLoadRequested);
    on<VocabularyAddRequested>(_onVocabularyAddRequested);
    on<VocabularyUpdateRequested>(_onVocabularyUpdateRequested);
    // ✅ NEW: Register Delete Handler
    on<VocabularyDeleteRequested>(_onVocabularyDeleteRequested);
  }

  Future<void> _onVocabularyLoadRequested(
    VocabularyLoadRequested event,
    Emitter<VocabularyState> emit,
  ) async {
    emit(VocabularyLoading());
    try {
      final items = await vocabularyService.getVocabulary(event.userId);
      emit(VocabularyLoaded(items));
    } catch (e) {
      emit(VocabularyError(e.toString()));
    }
  }

  Future<void> _onVocabularyAddRequested(
    VocabularyAddRequested event,
    Emitter<VocabularyState> emit,
  ) async {
    try {
      await vocabularyService.addVocabulary(event.item);
      add(VocabularyLoadRequested(event.item.userId));
    } catch (e) {
      emit(VocabularyError(e.toString()));
    }
  }

  Future<void> _onVocabularyUpdateRequested(
    VocabularyUpdateRequested event,
    Emitter<VocabularyState> emit,
  ) async {
    try {
      await vocabularyService.updateVocabulary(event.item);
      if (state is VocabularyLoaded) {
        final currentItems = (state as VocabularyLoaded).items;
        final updatedItems = currentItems.map((item) {
          return item.id == event.item.id ? event.item : item;
        }).toList();
        emit(VocabularyLoaded(updatedItems));
      }
    } catch (e) {
      emit(VocabularyError(e.toString()));
    }
  }

  // ✅ NEW: Handle Delete
  Future<void> _onVocabularyDeleteRequested(
    VocabularyDeleteRequested event,
    Emitter<VocabularyState> emit,
  ) async {
    try {
      // 1. Call Service to delete from Firebase
      await vocabularyService.deleteVocabulary(event.userId, event.id);

      // 2. Update Local State immediately (Optimistic Update)
      if (state is VocabularyLoaded) {
        final currentItems = (state as VocabularyLoaded).items;
        // Filter out the deleted item
        final updatedItems = currentItems.where((item) => item.id != event.id).toList();
        emit(VocabularyLoaded(updatedItems));
      }
    } catch (e) {
      emit(VocabularyError("Failed to delete item: ${e.toString()}"));
    }
  }
}