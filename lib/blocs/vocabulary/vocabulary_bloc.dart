import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/models/vocabulary_item.dart';
import 'package:linguaflow/services/vocabulary_service.dart';

// Import the separated files
import 'vocabulary_event.dart';
import 'vocabulary_state.dart';

// Re-export them so other files only need to import the Bloc
export 'vocabulary_event.dart';
export 'vocabulary_state.dart';

class VocabularyBloc extends Bloc<VocabularyEvent, VocabularyState> {
  final VocabularyService vocabularyService;

  VocabularyBloc(this.vocabularyService) : super(VocabularyInitial()) {
    on<VocabularyLoadRequested>(_onVocabularyLoadRequested);
    on<VocabularyAddRequested>(_onVocabularyAddRequested);
    on<VocabularyUpdateRequested>(_onVocabularyUpdateRequested);
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
      VocabularyItem itemToAdd = event.item;
      
      // STATS LOGIC: If adding a word directly as "Known", mark the date immediately
      // This counts towards "Velocity"
      if (itemToAdd.status > 0 && itemToAdd.learnedAt == null) {
        itemToAdd = itemToAdd.copyWith(learnedAt: DateTime.now());
      }
      
      await vocabularyService.addVocabulary(itemToAdd);
      
      // Reload to ensure sync
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
      VocabularyItem updatedItem = event.item;

      // --- STATS LOGIC: TRACK LEARNING VELOCITY ---
      // We check if the word is graduating from "New" (0) to "Learning/Known" (>0)
      if (state is VocabularyLoaded) {
        final currentItems = (state as VocabularyLoaded).items;
        
        // Find the old version of this word to compare status
        final oldItem = currentItems.firstWhere(
            (i) => i.id == updatedItem.id, 
            orElse: () => updatedItem
        );

        // If it was status 0 (New) and is now > 0 (Known/Learning), 
        // we stamp it with today's date.
        if (oldItem.status == 0 && updatedItem.status > 0) {
           updatedItem = updatedItem.copyWith(learnedAt: DateTime.now());
        }
      }

      // 1. Save to Database
      await vocabularyService.updateVocabulary(updatedItem);

      // 2. Optimistic UI Update (Update state immediately without waiting for reload)
      if (state is VocabularyLoaded) {
        final currentItems = (state as VocabularyLoaded).items;
        final updatedList = currentItems.map((item) {
          return item.id == updatedItem.id ? updatedItem : item;
        }).toList();
        
        emit(VocabularyLoaded(updatedList));
      }
    } catch (e) {
      emit(VocabularyError(e.toString()));
    }
  }

  Future<void> _onVocabularyDeleteRequested(
    VocabularyDeleteRequested event,
    Emitter<VocabularyState> emit,
  ) async {
    try {
      // 1. Delete from Database
      await vocabularyService.deleteVocabulary(event.userId, event.id);
      
      // 2. Optimistic UI Update
      if (state is VocabularyLoaded) {
        final currentItems = (state as VocabularyLoaded).items;
        final updatedItems = currentItems.where((item) => item.id != event.id).toList();
        emit(VocabularyLoaded(updatedItems));
      }
    } catch (e) {
      emit(VocabularyError("Failed to delete item: ${e.toString()}"));
    }
  }
}