import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/blocs/settings/settings_bloc.dart';
import 'package:linguaflow/models/vocabulary_item.dart';
import '../reader_utils.dart';
import 'package:linguaflow/utils/language_helper.dart';

class InteractiveTextDisplay extends StatefulWidget {
  final String text;
  final String language;
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
    required this.language,
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
    if (oldWidget.text != widget.text ||
        oldWidget.language != widget.language) {
      _processText();
      _cancelSelection();
      _isRevealed = false;
    }
    if (oldWidget.isListeningMode && !widget.isListeningMode) {
      _isRevealed = true;
    }
  }

  void _processText() {
    _tokens = LanguageHelper.tokenizeText(widget.text, widget.language);
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

  // Helper Mock Item for consistent coloring logic
  VocabularyItem _mockItem(int status) {
    return VocabularyItem(
      id: 'mock',
      userId: 'mock',
      word: 'mock',
      baseForm: 'mock',
      language: 'en',
      translation: '',
      status: status,
      timesEncountered: 0,
      lastReviewed: DateTime.now(),
      createdAt: DateTime.now(),
    );
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

    final Color overlayBlack = Colors.black.withValues(alpha: 0.6);
    final bool isScriptioContinua = LanguageHelper.usesNoSpaces(
      widget.text,
      widget.language,
    );

    Widget textContent = Wrap(
      spacing: 0,
      runSpacing: widget.isBigMode ? 12 : 8,
      alignment: (widget.isBigMode || widget.isOverlay)
          ? WrapAlignment.center
          : WrapAlignment.start,
      textDirection: LanguageHelper.isRTL(widget.language)
          ? TextDirection.rtl
          : TextDirection.ltr,

      children: List.generate(_tokens.length, (index) {
        final token = _tokens[index];

        // 1. HIDE ACTUAL SPACE TOKENS
        // We let the word padding create the visual space.
        if (token.trim().isEmpty) return const SizedBox.shrink();

        // 2. Identification
        final String cleanWord = ReaderUtils.generateCleanId(token);
        final bool isInteractable = cleanWord.isNotEmpty;

        // 3. Selection Logic
        bool isSelected = false;
        if (_isDragging && _startIndex != -1 && _endIndex != -1) {
          final start = _startIndex < _endIndex ? _startIndex : _endIndex;
          final end = _startIndex < _endIndex ? _endIndex : _startIndex;
          if (index >= start && index <= end) isSelected = true;
        }

        // --- COLOR LOGIC ---
        Color containerColor = Colors.transparent;
        Color textColor = isDark ? Colors.white : Colors.black;

        if (widget.isOverlay) {
          if (!isInteractable) {
            containerColor = overlayBlack;
            textColor = Colors.white;
          } else {
            final vocabItem = widget.vocabulary[cleanWord];
            final int status = vocabItem?.status ?? 0;

            if (status == 0) {
              containerColor = Colors.blue.withValues(alpha: 0.8);
              textColor = Colors.white;
            } else if (status < 5) {
              Color rawColor = ReaderUtils.getWordColor(
                _mockItem(status),
                true,
              );
              containerColor = rawColor.withValues(alpha: 0.9);
              textColor = (status <= 3) ? Colors.black : Colors.white;
            } else {
              containerColor = overlayBlack;
              textColor = Colors.white;
            }
          }
        } else {
          // Normal Mode
          if (!isInteractable) {
            containerColor = Colors.transparent;
            textColor = isDark ? Colors.white : Colors.black87;
          } else {
            final vocabItem = widget.vocabulary[cleanWord];
            final int status = vocabItem?.status ?? 0;

            if (status < 5) {
              containerColor = ReaderUtils.getWordColor(
                _mockItem(status),
                isDark,
              );
            } else {
              containerColor = Colors.transparent;
            }
            textColor = ReaderUtils.getTextColorForStatus(
              vocabItem,
              isSelected,
              isDark,
            );
          }
        }

        if (isSelected) {
          containerColor = Colors.purple.withValues(alpha: 0.8);
          textColor = Colors.white;
        }

        // --- PADDING (This acts as the Space) ---
        // Since we removed margins, we increase padding slightly to keep words readable.
        EdgeInsetsGeometry padding;
        if (isScriptioContinua) {
          // CJK: Tiny padding
          padding = const EdgeInsets.symmetric(horizontal: 1.0, vertical: 2.0);
        } else {
          if (isInteractable) {
            // Words: 4.0 padding on both sides = 8.0 visual gap between words.
            padding = const EdgeInsets.symmetric(
              horizontal: 4.0,
              vertical: 2.0,
            );
          } else {
            // Punctuation: Tighter padding so it sticks closer to words
            padding = const EdgeInsets.symmetric(
              horizontal: 1.5,
              vertical: 2.0,
            );
          }
        }

        return GestureDetector(
          key: _tokenKeys[index],
          onTapUp: (details) {
            if (isInteractable && !isObscured && !_isDragging) {
              final String wordForDict = token.replaceAll(
                RegExp(r'^[^\p{L}\p{N}]+|[^\p{L}\p{N}]+$', unicode: true),
                '',
              );
              if (wordForDict.isNotEmpty) {
                widget.onWordTap(
                  wordForDict,
                  cleanWord,
                  details.globalPosition,
                );
              }
            }
          },
          behavior: HitTestBehavior.translucent,
          child: Container(
            // FIX: Removed Margin completely to allow colors to touch/join
            margin: EdgeInsets.zero,
            padding: padding,
            decoration: BoxDecoration(
              color: containerColor,
              // Rounded corners (4.0 for Normal, 0 for Overlay if you want seamless block)
              borderRadius: BorderRadius.circular(widget.isOverlay ? 0 : 4),
              border: isSelected
                  ? Border.all(color: Colors.white, width: 1)
                  : null,
            ),
            child: Text(
              token,
              style: TextStyle(
                fontSize: finalFontSize,
                height: lineHeight,
                color: textColor,
                fontWeight: FontWeight.normal,
                fontFamily: ['am', 'ti'].contains(widget.language)
                    ? 'Kefa'
                    : null,
                shadows: (widget.isOverlay && containerColor == overlayBlack)
                    ? [
                        const Shadow(
                          offset: Offset(0, 1),
                          blurRadius: 2,
                          color: Colors.black,
                        ),
                      ]
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
                  Text(
                    "Tap to Reveal",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onPanStart: (details) => _onPanStart(details),
      onPanUpdate: (details) => _onPanUpdate(details),
      onPanEnd: (details) => _onPanEnd(details),
      child: textContent,
    );
  }

  // ... (Keep existing _onPan methods) ...
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
}
