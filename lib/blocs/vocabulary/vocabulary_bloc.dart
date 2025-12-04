
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
}