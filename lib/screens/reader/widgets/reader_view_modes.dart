import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/models/vocabulary_item.dart';
import 'interactive_text_display.dart';

class SentenceModeView extends StatelessWidget {
  final List<String> chunks;
  final int activeIndex;
  final Map<String, VocabularyItem> vocabulary;
  final bool isVideo;
  final bool isPlaying;
  final bool isTtsPlaying;

  // Callbacks
  final Function() onTogglePlayback; // Middle Button
  final Function() onPlayFromStartContinuous; // Left Button
  final Function() onPlayContinuous; // Right Button

  final Function() onNext;
  final Function() onPrev;
  final Function(String, String, Offset) onWordTap;
  final Function(String phrase, Offset pos, VoidCallback clearSelection) onPhraseSelected;

  final bool isLoadingTranslation;
  final String? googleTranslation;
  final String? myMemoryTranslation;
  final bool showError;
  final Function() onRetryTranslation;
  final Function() onTranslateRequest;

  final bool isListeningMode;

  const SentenceModeView({
    super.key,
    required this.chunks,
    required this.activeIndex,
    required this.vocabulary,
    required this.isVideo,
    required this.isPlaying,
    required this.isTtsPlaying,
    required this.onTogglePlayback,
    required this.onPlayFromStartContinuous,
    required this.onPlayContinuous,
    required this.onNext,
    required this.onPrev,
    required this.onWordTap,
    required this.onPhraseSelected,
    required this.isLoadingTranslation,
    required this.googleTranslation,
    required this.myMemoryTranslation,
    required this.showError,
    required this.onRetryTranslation,
    required this.onTranslateRequest,
    this.isListeningMode = false,
  });

  @override
  Widget build(BuildContext context) {
    if (chunks.isEmpty) return const Center(child: Text("No content"));
    final safeIndex = activeIndex.clamp(0, chunks.length - 1);
    final currentText = chunks[safeIndex];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white : Colors.black87;

    return Column(
      children: [
        const SizedBox(height: 20),

        // --- UPDATED CONTROLS ROW ---
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 1. BACKWARD BUTTON (Start of sentence, Continuous)
            IconButton(
              icon: const Icon(FontAwesomeIcons.arrowRotateLeft),
              iconSize: 28,
              color: iconColor.withOpacity(0.7),
              tooltip: "Play from start (Continuous)",
              onPressed: onPlayFromStartContinuous,
            ),

            const SizedBox(width: 24),

            // 2. MIDDLE BUTTON (Play/Pause Single)
            GestureDetector(
              onTap: onTogglePlayback,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: (isDark ? Colors.white : Colors.black).withOpacity(0.5),
                    width: 2,
                  ),
                ),
                child: Icon(
                  isVideo
                      ? (isPlaying ? Icons.pause : Icons.play_arrow)
                      : (isTtsPlaying ? Icons.stop : Icons.play_arrow),
                  size: 40,
                  color: iconColor,
                ),
              ),
            ),

            const SizedBox(width: 24),

            // 3. FORWARD BUTTON (Continue Playing, Continuous)
            IconButton(
              icon: const Icon(FontAwesomeIcons.arrowRotateRight),
              iconSize: 28,
              color: iconColor.withOpacity(0.7),
              tooltip: "Continue playing",
              onPressed: onPlayContinuous,
            ),
          ],
        ),

        // Text Content
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity! < 0) onNext();
              if (details.primaryVelocity! > 0) onPrev();
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              alignment: Alignment.center,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    InteractiveTextDisplay(
                      text: currentText,
                      sentenceIndex: safeIndex,
                      vocabulary: vocabulary,
                      isBigMode: true,
                      onWordTap: onWordTap,
                      onPhraseSelected: onPhraseSelected,
                      isListeningMode: isListeningMode,
                    ),
                    const SizedBox(height: 24),
                    _buildTranslationSection(context),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTranslationSection(BuildContext context) {
    final bool hasTranslation = googleTranslation != null || myMemoryTranslation != null;

    if (isLoadingTranslation) {
      return const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (!hasTranslation && showError) {
      return Column(
        children: [
          Text(
            "Translation unavailable",
            style: TextStyle(
              color: Colors.red[300],
              fontSize: 13,
              fontStyle: FontStyle.italic,
            ),
          ),
          TextButton(onPressed: onRetryTranslation, child: const Text("Retry")),
        ],
      );
    } else {
      return Column(
        children: [
          if (hasTranslation) ...[
            if (myMemoryTranslation != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  myMemoryTranslation!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                    fontSize: 16,
                  ),
                ),
              ),
            if (googleTranslation != null)
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: Text(
                  "$googleTranslation",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontStyle: FontStyle.italic,
                    fontSize: 14,
                  ),
                ),
              ),
            const SizedBox(height: 12),
          ],

          TextButton.icon(
            icon: Icon(
              hasTranslation ? Icons.visibility_off : Icons.translate,
              size: 16,
              color: Colors.grey,
            ),
            label: Text(
              hasTranslation ? "Hide Translation" : "Translate Sentence",
              style: const TextStyle(color: Colors.grey),
            ),
            onPressed: onTranslateRequest,
          ),
        ],
      );
    }
  }
}

class ParagraphModeView extends StatelessWidget {
  final LessonModel lesson;
  final List<List<int>> bookPages;
  final int activeSentenceIndex;
  final int currentPage;
  final Map<String, VocabularyItem> vocabulary;
  final bool isVideo;
  final ScrollController listScrollController;
  final PageController pageController;
  final Function(int) onPageChanged;
  final Function(int) onSentenceTap;
  final Function(double) onVideoSeek;
  final Function(String, String, Offset) onWordTap;
  final Function(String phrase, Offset pos, VoidCallback clearSelection) onPhraseSelected;
  final bool isListeningMode;
  
  // --- ADDED: KEYS FOR AUTO-SCROLL ---
  final List<GlobalKey> itemKeys; 

  const ParagraphModeView({
    super.key,
    required this.lesson,
    required this.bookPages,
    required this.activeSentenceIndex,
    required this.currentPage,
    required this.vocabulary,
    required this.isVideo,
    required this.listScrollController,
    required this.pageController,
    required this.onPageChanged,
    required this.onSentenceTap,
    required this.onVideoSeek,
    required this.onWordTap,
    required this.onPhraseSelected,
    required this.itemKeys, // Required
    this.isListeningMode = false,
  });

  @override
  Widget build(BuildContext context) {
    if (lesson.transcript.isNotEmpty) {
      return ListView.separated(
        controller: listScrollController,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        itemCount: lesson.transcript.length + 1,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == lesson.transcript.length) return const SizedBox(height: 100);
          final entry = lesson.transcript[index];
          return _buildTranscriptRow(
            context,
            index,
            entry.text,
            entry.start,
            index == activeSentenceIndex,
          );
        },
      );
    }

    if (bookPages.isEmpty) return const Center(child: CircularProgressIndicator());

    return PageView.builder(
      controller: pageController,
      itemCount: bookPages.length,
      onPageChanged: onPageChanged,
      itemBuilder: (context, pageIndex) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...bookPages[pageIndex].map((idx) => _buildBookRow(
                  context, idx, lesson.sentences[idx], idx == activeSentenceIndex)),
              const SizedBox(height: 100),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTranscriptRow(BuildContext context, int index, String text, double start, bool isActive) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      // --- ASSIGN KEY HERE ---
      key: index < itemKeys.length ? itemKeys[index] : null,
      margin: const EdgeInsets.only(bottom: 12),
      padding: isActive ? const EdgeInsets.all(12) : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: isActive ? (isDark ? Colors.white10 : Colors.grey[100]) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isVideo)
            GestureDetector(
              onTap: () => onVideoSeek(start),
              child: Padding(
                padding: const EdgeInsets.only(top: 4, right: 12),
                child: Icon(
                  isActive ? Icons.play_arrow : Icons.play_arrow_outlined,
                  color: isActive ? Colors.blue : Colors.grey[400],
                  size: 24,
                ),
              ),
            ),
          Expanded(
            child: InteractiveTextDisplay(
              text: text,
              sentenceIndex: index,
              vocabulary: vocabulary,
              onWordTap: onWordTap,
              onPhraseSelected: onPhraseSelected,
              isListeningMode: isListeningMode,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookRow(BuildContext context, int index, String text, bool isActive) {
    return GestureDetector(
      onDoubleTap: () => onSentenceTap(index),
      child: Container(
        // --- ASSIGN KEY HERE ---
        key: index < itemKeys.length ? itemKeys[index] : null,
        margin: const EdgeInsets.only(bottom: 24),
        padding: isActive ? const EdgeInsets.all(12) : EdgeInsets.zero,
        decoration: BoxDecoration(
          color: isActive ? Colors.yellow.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: InteractiveTextDisplay(
          text: text,
          sentenceIndex: index,
          vocabulary: vocabulary,
          onWordTap: onWordTap,
          onPhraseSelected: onPhraseSelected,
          isListeningMode: isListeningMode,
        ),
      ),
    );
  }
}