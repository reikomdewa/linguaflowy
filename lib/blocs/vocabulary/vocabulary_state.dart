import 'package:linguaflow/models/vocabulary_item.dart';

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