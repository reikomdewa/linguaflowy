import 'package:flutter/material.dart';
import 'package:linguaflow/models/vocabulary_item.dart';
import 'package:linguaflow/screens/reader/reader_utils.dart';

/// A widget that displays a sentence, handles word coloring,
/// single word taps, and smooth DRAG SELECTION for phrases.
class InteractiveTextDisplay extends StatefulWidget {
  final String text;
  final int sentenceIndex;
  final Map<String, VocabularyItem> vocabulary;
  final Function(String word, String cleanId, Offset pos) onWordTap;
  final Function(String phrase, Offset pos) onPhraseSelected;
  final bool isBigMode;
  final bool isOverlay;

  const InteractiveTextDisplay({
    super.key,
    required this.text,
    required this.sentenceIndex,
    required this.vocabulary,
    required this.onWordTap,
    required this.onPhraseSelected,
    this.isBigMode = false,
    this.isOverlay = false,
  });

  @override
  State<InteractiveTextDisplay> createState() => _InteractiveTextDisplayState();
}

class _InteractiveTextDisplayState extends State<InteractiveTextDisplay> {
  // We keep keys for every word to perform hit-testing during drag
  final List<GlobalKey> _wordKeys = [];
  List<String> _words = [];

  // Selection State
  bool _isDragging = false;
  int _startIndex = -1;
  int _endIndex = -1;
  Offset _lastDragPos = Offset.zero;

  @override
  void initState() {
    super.initState();
    _processText();
  }

  @override
  void didUpdateWidget(covariant InteractiveTextDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _processText();
      _clearSelection();
    }
  }

  void _processText() {
    _words = widget.text.split(RegExp(r'(\s+)'));
    _wordKeys.clear();
    for (int i = 0; i < _words.length; i++) {
      _wordKeys.add(GlobalKey());
    }
  }

  void _clearSelection() {
    if (mounted) {
      setState(() {
        _isDragging = false;
        _startIndex = -1;
        _endIndex = -1;
      });
    }
  }

  /// Calculates which word index is under the user's finger
  int _getWordIndexFromPosition(Offset globalPosition) {
    for (int i = 0; i < _wordKeys.length; i++) {
      final key = _wordKeys[i];
      final context = key.currentContext;
      if (context != null) {
        final renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox != null) {
          // Check if the touch point is within this word's bounds
          final localPosition = renderBox.globalToLocal(globalPosition);
          final size = renderBox.size;
          if (localPosition.dx >= 0 &&
              localPosition.dx <= size.width &&
              localPosition.dy >= 0 &&
              localPosition.dy <= size.height) {
            return i;
          }
        }
      }
    }
    return -1;
  }

  void _onPanStart(DragStartDetails details) {
    int index = _getWordIndexFromPosition(details.globalPosition);
    if (index != -1) {
      setState(() {
        _isDragging = true;
        _startIndex = index;
        _endIndex = index;
        _lastDragPos = details.globalPosition;
      });
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    int index = _getWordIndexFromPosition(details.globalPosition);
    if (index != -1 && index != _endIndex) {
      setState(() {
        _endIndex = index;
        _lastDragPos = details.globalPosition;
      });
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (_startIndex != -1 && _endIndex != -1) {
      final start = _startIndex < _endIndex ? _startIndex : _endIndex;
      final end = _startIndex < _endIndex ? _endIndex : _startIndex;
      
      // Combine the words into a phrase
      final phrase = _words.sublist(start, end + 1).join("");
      
      // If it's just one word (and it was a drag, not a tap), treat as phrase 
      // or if it's multiple words.
      if (phrase.trim().isNotEmpty) {
        widget.onPhraseSelected(phrase.trim(), _lastDragPos);
      }
    }
    _clearSelection();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    double fontSize = widget.isBigMode ? 22 : 18;
    if (widget.isOverlay) fontSize = 20;
    
    // We wrap the whole text block in a GestureDetector to handle dragging
    // across multiple words smoothly.
    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: Wrap(
        spacing: 0,
        runSpacing: widget.isBigMode ? 12 : 6,
        alignment: (widget.isBigMode || widget.isOverlay) 
            ? WrapAlignment.center 
            : WrapAlignment.start,
        children: List.generate(_words.length, (index) {
          final word = _words[index];
          final cleanWord = ReaderUtils.generateCleanId(word);

          // Determine Selection
          bool isSelected = false;
          if (_isDragging && _startIndex != -1 && _endIndex != -1) {
             final start = _startIndex < _endIndex ? _startIndex : _endIndex;
             final end = _startIndex < _endIndex ? _endIndex : _startIndex;
             if (index >= start && index <= end) isSelected = true;
          }

          // Determine Style
          final vocabItem = widget.vocabulary[cleanWord];
          Color bgColor = ReaderUtils.getWordColor(vocabItem, isDark);
          Color textColor = ReaderUtils.getTextColorForStatus(vocabItem, isSelected, isDark);
          
          if (widget.isOverlay) {
             textColor = Colors.white;
             if (bgColor != Colors.transparent && bgColor != Colors.blue.withOpacity(0.15)) {
               bgColor = bgColor.withOpacity(0.8);
               textColor = Colors.black;
             }
          }

          if (isSelected) {
            bgColor = Colors.purple.withOpacity(0.4);
            textColor = Colors.white;
          }

          // Render Word
          return GestureDetector(
            key: _wordKeys[index], // Important for hit testing
            onTapUp: (details) {
              if (!_isDragging) {
                widget.onWordTap(word, cleanWord, details.globalPosition);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(4),
                border: isSelected ? Border.all(color: Colors.purple, width: 1) : null,
              ),
              child: Text(
                word,
                style: TextStyle(
                  fontSize: fontSize,
                  height: 1.5,
                  color: textColor,
                  fontWeight: (vocabItem?.status ?? 0) > 0 ? FontWeight.w600 : FontWeight.normal,
                  shadows: widget.isOverlay
                      ? [const Shadow(offset: Offset(0, 1), blurRadius: 2, color: Colors.black)]
                      : null,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}