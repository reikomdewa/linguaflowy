import 'package:equatable/equatable.dart';
import 'package:linguaflow/models/vocabulary_item.dart';

abstract class VocabularyState extends Equatable {
  const VocabularyState();
  
  @override
  List<Object?> get props => [];
}

class VocabularyInitial extends VocabularyState {}

class VocabularyLoading extends VocabularyState {}

class VocabularyLoaded extends VocabularyState {
  final List<VocabularyItem> items;

  const VocabularyLoaded(this.items);

  @override
  List<Object?> get props => [items];
}

class VocabularyError extends VocabularyState {
  final String message;

  const VocabularyError(this.message);

  @override
  List<Object?> get props => [message];
}