import 'package:linguaflow/models/vocabulary_item.dart';

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

class VocabularyDeleteRequested extends VocabularyEvent {
  final String id;
  VocabularyDeleteRequested(this.id);
}