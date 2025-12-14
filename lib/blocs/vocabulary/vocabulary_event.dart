import 'package:equatable/equatable.dart';
import 'package:linguaflow/models/vocabulary_item.dart';

abstract class VocabularyEvent extends Equatable {
  const VocabularyEvent();

  @override
  List<Object?> get props => [];
}

class VocabularyLoadRequested extends VocabularyEvent {
  final String userId;

  const VocabularyLoadRequested(this.userId);

  @override
  List<Object?> get props => [userId];
}

class VocabularyAddRequested extends VocabularyEvent {
  final VocabularyItem item;

  const VocabularyAddRequested(this.item);

  @override
  List<Object?> get props => [item];
}

class VocabularyUpdateRequested extends VocabularyEvent {
  final VocabularyItem item;

  const VocabularyUpdateRequested(this.item);

  @override
  List<Object?> get props => [item];
}

class VocabularyDeleteRequested extends VocabularyEvent {
  final String id;
  final String userId;

  const VocabularyDeleteRequested({required this.id, required this.userId});

  @override
  List<Object?> get props => [id, userId];
}