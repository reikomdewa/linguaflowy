import 'dart:ui'; // Required for ImageFilter
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/blocs/settings/settings_bloc.dart'; 
import 'package:linguaflow/models/vocabulary_item.dart';
import '../reader_utils.dart';

class InteractiveTextDisplay extends StatefulWidget {
  final String text;
  final int sentenceIndex;
  final Map<String, VocabularyItem> vocabulary;
  final Function(String word, String cleanId, Offset pos) onWordTap;
  final Function(String phrase, Offset pos, VoidCallback clearSelection) onPhraseSelected;
  final bool isBigMode;
  final bool isOverlay;
  
  // NEW PROP
  final bool isListeningMode;

  const InteractiveTextDisplay({
    super.key,
    required this.text,
    required this.sentenceIndex,
    required this.vocabulary,
    required this.onWordTap,
    required this.onPhraseSelected,
    this.isBigMode = false,
    this.isOverlay = false,
    this.isListeningMode = false, // Default false
  });

  @override
  State<InteractiveTextDisplay> createState() => _InteractiveTextDisplayState();
}

class _InteractiveTextDisplayState extends State<InteractiveTextDisplay> {
  final List<GlobalKey> _wordKeys = [];
  List<String> _words = [];
  bool _isDragging = false;
  int _startIndex = -1;
  int _endIndex = -1;
  Offset _lastDragPos = Offset.zero;
  
  // State for Listening Mode
  bool _isRevealed = false;

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
      _cancelSelection();
      // Reset reveal state when sentence changes
      _isRevealed = false; 
    }
    // If mode is turned off, force reveal
    if (oldWidget.isListeningMode && !widget.isListeningMode) {
      _isRevealed = true;
    }
  }

  void _processText() {
    _words = widget.text.split(RegExp(r'(\s+)'));
    _wordKeys.clear();
    for (int i = 0; i < _words.length; i++) {
      _wordKeys.add(GlobalKey());
    }
  }

  void _cancelSelection() {
    if (mounted) setState(() { _isDragging = false; _startIndex = -1; _endIndex = -1; });
  }

  // ... (Hit testing & Pan Update methods - REMAIN SAME) ...
  int _getWordIndexFromPosition(Offset globalPosition) {
    for (int i = 0; i < _wordKeys.length; i++) {
      final key = _wordKeys[i];
      final context = key.currentContext;
      if (context != null) {
        final renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox != null) {
          final localPosition = renderBox.globalToLocal(globalPosition);
          final size = renderBox.size;
          if (localPosition.dx >= -5 && localPosition.dx <= size.width + 5 && localPosition.dy >= -5 && localPosition.dy <= size.height + 5) {
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
      setState(() { _isDragging = true; _startIndex = index; _endIndex = index; _lastDragPos = details.globalPosition; });
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    int index = _getWordIndexFromPosition(details.globalPosition);
    if (index != -1) {
      setState(() { _endIndex = index; _lastDragPos = details.globalPosition; });
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (_startIndex != -1 && _endIndex != -1) {
      final start = _startIndex < _endIndex ? _startIndex : _endIndex;
      final end = _startIndex < _endIndex ? _endIndex : _startIndex;
      final wordsOnly = _words.sublist(start, end + 1).where((w) => w.trim().isNotEmpty).toList();
      String phrase = wordsOnly.join(" ");
      if (phrase.trim().isNotEmpty) {
        widget.onPhraseSelected(phrase.trim(), _lastDragPos, _cancelSelection);
        return;
      }
    }
    _cancelSelection();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsBloc>().state;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    double baseSize = widget.isBigMode ? 22 : 18;
    if (widget.isOverlay) baseSize = 20;
    
    final finalFontSize = baseSize * settings.fontSizeScale;
    final lineHeight = settings.lineHeight;

    // Check if we should hide text
    // Hidden if: Mode is ON AND it hasn't been revealed yet.
    final bool isObscured = widget.isListeningMode && !_isRevealed;

    Widget textContent = Wrap(
      spacing: 0,
      runSpacing: widget.isBigMode ? 12 : 6,
      alignment: (widget.isBigMode || widget.isOverlay) ? WrapAlignment.center : WrapAlignment.start,
      children: List.generate(_words.length, (index) {
        final word = _words[index];
        final cleanWord = ReaderUtils.generateCleanId(word);
        if (word.isEmpty) return const SizedBox.shrink();

        bool isSelected = false;
        if (_isDragging && _startIndex != -1 && _endIndex != -1) {
          final start = _startIndex < _endIndex ? _startIndex : _endIndex;
          final end = _startIndex < _endIndex ? _endIndex : _startIndex;
          if (index >= start && index <= end) isSelected = true;
        }

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

        return GestureDetector(
          key: _wordKeys[index],
          onTapUp: (details) {
            // ONLY ALLOW WORD TAP IF NOT OBSCURED
            if (!isObscured && !_isDragging) {
              widget.onWordTap(word, cleanWord, details.globalPosition);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 2),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(4),
              border: isSelected ? Border.all(color: Colors.purple, width: 1) : null,
            ),
            child: Text(
              word,
              style: TextStyle(
                fontSize: finalFontSize,
                height: lineHeight,
                color: textColor,
                fontWeight: (vocabItem?.status ?? 0) > 0 ? FontWeight.w600 : FontWeight.normal,
                shadows: widget.isOverlay ? [const Shadow(offset: Offset(0, 1), blurRadius: 2, color: Colors.black)] : null,
              ),
            ),
          ),
        );
      }),
    );

    // If Obscured, wrap the whole thing in a Blur and a Tap Detector
    if (isObscured) {
      return GestureDetector(
        onTap: () {
          setState(() {
            _isRevealed = true; // REVEAL ON TAP
          });
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            // The Blurred Text
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Opacity(
                opacity: 0.6, // Slight opacity to make it look "behind glass"
                child: textContent,
              ),
            ),
            
            // The "Tap to Reveal" Hint
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.visibility, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    "Tap to Reveal",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Normal Mode: Allow Drag Selection
    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: textContent,
    );
  }
}