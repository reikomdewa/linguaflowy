
// File: lib/screens/reader/reader_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/vocabulary/vocabulary_bloc.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/models/user_model.dart';
import 'package:linguaflow/models/vocabulary_item.dart';
import 'package:linguaflow/services/translation_service.dart';
import 'package:linguaflow/services/vocabulary_service.dart';

class ReaderScreen extends StatefulWidget {
  final LessonModel lesson;

  const ReaderScreen({required this.lesson});

  @override
  _ReaderScreenState createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  Map<String, VocabularyItem> _vocabulary = {};
  String? _selectedWord;
  int _selectedWordIndex = -1;

  @override
  void initState() {
    super.initState();
    _loadVocabulary();
  }

  Future<void> _loadVocabulary() async {
    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
    final vocabService = context.read<VocabularyService>();
    final items = await vocabService.getVocabulary(user.id);
    
    setState(() {
      _vocabulary = {
        for (var item in items) item.word.toLowerCase(): item
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.lesson.title),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.blue.withOpacity(0.1),
            child: Row(
              children: [
                Icon(Icons.language, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  widget.lesson.language.toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                Spacer(),
                Text(
                  '${widget.lesson.sentences.length} sentences',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: widget.lesson.sentences.asMap().entries.map((entry) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: 20),
                    child: _buildSentence(entry.value, entry.key),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSentence(String sentence, int sentenceIndex) {
    final words = sentence.split(RegExp(r'(\s+)'));
    
    return Wrap(
      children: words.map((word) {
        final cleanWord = word.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
        if (cleanWord.isEmpty || word.trim().isEmpty) {
          return Text(word, style: TextStyle(fontSize: 18));
        }

        final vocabItem = _vocabulary[cleanWord];
        final color = _getWordColor(vocabItem);

        return GestureDetector(
          onTap: () => _onWordTap(cleanWord, word, sentenceIndex),
          child: Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
            padding: EdgeInsets.symmetric(horizontal: 2, vertical: 1),
            child: Text(
              word,
              style: TextStyle(
                fontSize: 18,
                height: 1.6,
                color: vocabItem?.status == 5 ? Colors.black87 : null,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Color _getWordColor(VocabularyItem? item) {
    if (item == null) return Colors.blue.withOpacity(0.2);
    
    switch (item.status) {
      case 0:
        return Colors.blue.withOpacity(0.3);
      case 1:
        return Colors.yellow.withOpacity(0.3);
      case 2:
        return Colors.orange.withOpacity(0.25);
      case 3:
        return Colors.orange.withOpacity(0.35);
      case 4:
        return Colors.orange.withOpacity(0.45);
      case 5:
        return Colors.transparent;
      default:
        return Colors.grey.withOpacity(0.2);
    }
  }

  void _onWordTap(String cleanWord, String originalWord, int wordIndex) {
    setState(() {
      _selectedWord = cleanWord;
      _selectedWordIndex = wordIndex;
    });

    _showWordDialog(cleanWord, originalWord);
  }

  void _showWordDialog(String cleanWord, String originalWord) async {
    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
    final vocabService = context.read<VocabularyService>();
    final translationService = context.read<TranslationService>();

    VocabularyItem? existingItem = _vocabulary[cleanWord];
    String translation = existingItem?.translation ?? 'Loading...';

    if (existingItem == null) {
      // Fetch translation
      translation = await translationService.translate(
        cleanWord,
        user.nativeLanguage,
        widget.lesson.language,
      );
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                  Text(
                    originalWord,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      widget.lesson.language.toUpperCase(),
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                  Text(
                    'Translation',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    translation,
                    style: TextStyle(fontSize: 20),
                  ),
                  SizedBox(height: 32),
                  Text(
                    'Status',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _StatusButton(
                        label: 'New',
                        status: 0,
                        color: Colors.blue,
                        onTap: () => _updateWordStatus(
                          cleanWord,
                          originalWord,
                          translation,
                          0,
                        ),
                      ),
                      _StatusButton(
                        label: 'Learning 1',
                        status: 1,
                        color: Colors.yellow[700]!,
                        onTap: () => _updateWordStatus(
                          cleanWord,
                          originalWord,
                          translation,
                          1,
                        ),
                      ),
                      _StatusButton(
                        label: 'Learning 2',
                        status: 2,
                        color: Colors.orange[600]!,
                        onTap: () => _updateWordStatus(
                          cleanWord,
                          originalWord,
                          translation,
                          2,
                        ),
                      ),
                      _StatusButton(
                        label: 'Learning 3',
                        status: 3,
                        color: Colors.orange[700]!,
                        onTap: () => _updateWordStatus(
                          cleanWord,
                          originalWord,
                          translation,
                          3,
                        ),
                      ),
                      _StatusButton(
                        label: 'Learning 4',
                        status: 4,
                        color: Colors.orange[800]!,
                        onTap: () => _updateWordStatus(
                          cleanWord,
                          originalWord,
                          translation,
                          4,
                        ),
                      ),
                      _StatusButton(
                        label: 'Known',
                        status: 5,
                        color: Colors.green,
                        onTap: () => _updateWordStatus(
                          cleanWord,
                          originalWord,
                          translation,
                          5,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _updateWordStatus(
                      cleanWord,
                      originalWord,
                      translation,
                      -1,
                    ),
                    icon: Icon(Icons.block),
                    label: Text('Ignore Word'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      minimumSize: Size(double.infinity, 48),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _updateWordStatus(
    String cleanWord,
    String originalWord,
    String translation,
    int status,
  ) async {
    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
    final vocabService = context.read<VocabularyService>();

    VocabularyItem? existingItem = _vocabulary[cleanWord];

    if (existingItem != null) {
      final updatedItem = existingItem.copyWith(
        status: status,
        timesEncountered: existingItem.timesEncountered + 1,
      );
      context.read<VocabularyBloc>().add(VocabularyUpdateRequested(updatedItem));
      setState(() {
        _vocabulary[cleanWord] = updatedItem;
      });
    } else {
      final newItem = VocabularyItem(
        id: '',
        userId: user.id,
        word: cleanWord,
        baseForm: cleanWord,
        language: widget.lesson.language,
        translation: translation,
        status: status,
        timesEncountered: 1,
        lastReviewed: DateTime.now(),
        createdAt: DateTime.now(),
      );
      context.read<VocabularyBloc>().add(VocabularyAddRequested(newItem));
      setState(() {
        _vocabulary[cleanWord] = newItem;
      });
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Word updated!'),
        duration: Duration(seconds: 1),
      ),
    );
  }
}

class _StatusButton extends StatelessWidget {
  final String label;
  final int status;
  final Color color;
  final VoidCallback onTap;

  const _StatusButton({
    required this.label,
    required this.status,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
      ),
      child: Text(label),
    );
  }
}
