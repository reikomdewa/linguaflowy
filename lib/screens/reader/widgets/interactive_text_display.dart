import 'dart:ui';
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
  final Function(String phrase, Offset pos, VoidCallback clearSelection)
      onPhraseSelected;
  final bool isBigMode;
  final bool isOverlay;
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
    this.isListeningMode = false,
  });

  @override
  State<InteractiveTextDisplay> createState() => _InteractiveTextDisplayState();
}

class _InteractiveTextDisplayState extends State<InteractiveTextDisplay> {
  final List<GlobalKey> _tokenKeys = [];
  List<String> _tokens = [];
  bool _isDragging = false;
  int _startIndex = -1;
  int _endIndex = -1;
  Offset _lastDragPos = Offset.zero;
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
      _isRevealed = false;
    }
    if (oldWidget.isListeningMode && !widget.isListeningMode) {
      _isRevealed = true;
    }
  }

  void _processText() {
    // RESTORED: Original split logic that preserves spacing better
    _tokens = widget.text.split(RegExp(r'(\s+)'));
    
    _tokenKeys.clear();
    for (int i = 0; i < _tokens.length; i++) {
      _tokenKeys.add(GlobalKey());
    }
  }

  void _cancelSelection() {
    if (mounted) {
      setState(() {
        _isDragging = false;
        _startIndex = -1;
        _endIndex = -1;
      });
    }
  }

  int _getTokenIndexFromPosition(Offset globalPosition) {
    for (int i = 0; i < _tokenKeys.length; i++) {
      final key = _tokenKeys[i];
      final context = key.currentContext;
      if (context != null) {
        final renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox != null) {
          final localPosition = renderBox.globalToLocal(globalPosition);
          final size = renderBox.size;
          // Generous hit test area
          if (localPosition.dx >= -5 &&
              localPosition.dx <= size.width + 5 &&
              localPosition.dy >= -5 &&
              localPosition.dy <= size.height + 5) {
            return i;
          }
        }
      }
    }
    return -1;
  }

  void _onPanStart(DragStartDetails details) {
    int index = _getTokenIndexFromPosition(details.globalPosition);
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
    int index = _getTokenIndexFromPosition(details.globalPosition);
    if (index != -1) {
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
      final phrase = _tokens.sublist(start, end + 1).join("").trim();
      if (phrase.isNotEmpty) {
        widget.onPhraseSelected(phrase, _lastDragPos, _cancelSelection);
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
    final bool isObscured = widget.isListeningMode && !_isRevealed;

    final Color overlayBlack = Colors.black.withOpacity(0.6);

    Widget textContent = Wrap(
      spacing: 0, 
      runSpacing: widget.isBigMode ? 12 : 6,
      alignment: (widget.isBigMode || widget.isOverlay)
          ? WrapAlignment.center
          : WrapAlignment.start,
      children: List.generate(_tokens.length, (index) {
        final token = _tokens[index];
        if (token.isEmpty) return const SizedBox.shrink();

        final cleanWord = ReaderUtils.generateCleanId(token);
        final bool isSpace = token.trim().isEmpty;

        bool isSelected = false;
        if (_isDragging && _startIndex != -1 && _endIndex != -1) {
          final start = _startIndex < _endIndex ? _startIndex : _endIndex;
          final end = _startIndex < _endIndex ? _endIndex : _startIndex;
          if (index >= start && index <= end) isSelected = true;
        }

        // --- COLOR & STYLE LOGIC ---
        Color containerColor = Colors.transparent;
        Color textColor = isDark ? Colors.white : Colors.black;

        if (widget.isOverlay) {
          // --- OVERLAY MODE ---
          if (isSpace) {
            containerColor = overlayBlack; // Color the space black
          } else {
            final vocabItem = widget.vocabulary[cleanWord];

            if (vocabItem != null) {
              if (vocabItem.status == 0) {
                // BLUE (New Word) - High opacity
                containerColor = Colors.blue.withOpacity(0.8);
                textColor = Colors.white;
              } else {
                // SAVED (Yellow/Green/Red) - High opacity
                Color rawColor = ReaderUtils.getWordColor(vocabItem, true);
                if (rawColor == Colors.transparent) rawColor = Colors.yellow;
                
                containerColor = rawColor.withOpacity(0.9);
                // Smart text color for readability
                if (vocabItem.status <= 3) {
                  textColor = Colors.black;
                } else {
                  textColor = Colors.white;
                }
              }
            } else {
              // PLAIN WORD - Black background
              containerColor = overlayBlack;
              textColor = Colors.white;
            }
          }
        } else {
          // --- NORMAL MODE ---
          if (!isSpace) {
            final vocabItem = widget.vocabulary[cleanWord];
            containerColor = ReaderUtils.getWordColor(vocabItem, isDark);
            textColor = ReaderUtils.getTextColorForStatus(vocabItem, isSelected, isDark);
          }
        }

        // Selection Override
        if (isSelected) {
          containerColor = Colors.purple.withOpacity(0.8);
          textColor = Colors.white;
        }

        // --- PADDING LOGIC (FIX FOR SPACING) ---
        // Words get horizontal padding (your original look).
        // Spaces get 0 horizontal padding (so they don't become huge gaps).
        // In Overlay, we remove vertical padding slightly to make lines compact if needed,
        // but keeping horizontal padding for words ensures the highlight box isn't too tight.
        EdgeInsetsGeometry padding;
        if (isSpace) {
          // Spaces just need to fill the gap, no extra padding
          padding = widget.isOverlay 
              ? const EdgeInsets.symmetric(vertical: 2.0) // Match height
              : EdgeInsets.zero;
        } else {
          // Words get the nice spacing you liked
          padding = const EdgeInsets.symmetric(horizontal: 2.5, vertical: 2.0);
        }

        return GestureDetector(
          key: _tokenKeys[index],
          onTapUp: (details) {
            if (!isSpace && !isObscured && !_isDragging) {
              widget.onWordTap(token, cleanWord, details.globalPosition);
            }
          },
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: containerColor,
              // Round corners in normal mode, square in overlay for strip effect
              borderRadius: BorderRadius.circular(widget.isOverlay ? 0 : 4),
              border: isSelected ? Border.all(color: Colors.white, width: 1) : null,
            ),
            child: Text(
              token,
              style: TextStyle(
                fontSize: finalFontSize,
                height: lineHeight,
                color: textColor,
                fontWeight: (!isSpace && (widget.vocabulary[cleanWord]?.status ?? 0) > 0)
                    ? FontWeight.w600
                    : FontWeight.normal,
                shadows: (widget.isOverlay && containerColor == overlayBlack)
                    ? [const Shadow(offset: Offset(0, 1), blurRadius: 2, color: Colors.black)]
                    : null,
              ),
            ),
          ),
        );
      }),
    );

    if (isObscured) {
      return GestureDetector(
        onTap: () => setState(() => _isRevealed = true),
        child: Stack(
          alignment: Alignment.center,
          children: [
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Opacity(opacity: 0.6, child: textContent),
            ),
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
                  Text("Tap to Reveal",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: textContent,
    );
  }
}