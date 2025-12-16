
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/models/vocabulary_item.dart';
import 'interactive_text_display.dart';

// --- SENTENCE MODE (Flashcard Style) ---
class SentenceModeView extends StatelessWidget {
  final List<String> chunks;
  final int activeIndex;
  final Map<String, VocabularyItem> vocabulary;
  final bool isVideo;
  final bool isPlaying;
  final bool isTtsPlaying;
  final VoidCallback onTogglePlayback;
  final VoidCallback onPlayFromStartContinuous;
  final VoidCallback onPlayContinuous;
  final VoidCallback onNext;
  final VoidCallback onPrev;
  final Function(String, String, Offset) onWordTap;
  final Function(String phrase, Offset pos, VoidCallback clearSelection)
  onPhraseSelected;
  final bool isLoadingTranslation;
  final String? googleTranslation;
  final String? myMemoryTranslation;
  final bool showError;
  final VoidCallback onRetryTranslation;
  final VoidCallback onTranslateRequest;
  final bool isListeningMode;
  final String language; // <--- REQUIRED: Passed from Parent

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
    required this.language, // <--- Ensure this is passed!
    this.isListeningMode = false,
  });

  @override
  Widget build(BuildContext context) {
    if (chunks.isEmpty) return const Center(child: Text("No content"));

    // Ensure index is valid to prevent crashes
    final safeIndex = activeIndex.clamp(0, chunks.length - 1);
    final currentText = chunks[safeIndex];

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white : Colors.black87;

    return Column(
      children: [
        const SizedBox(height: 20),

        // --- CONTROLS ---
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Restart / Prev
            IconButton(
              icon: const Icon(FontAwesomeIcons.arrowRotateLeft),
              iconSize: 28,
              color: iconColor.withValues(alpha: 0.7),
              onPressed: onPlayFromStartContinuous,
              tooltip: "Restart Sentence",
            ),
            const SizedBox(width: 24),

            // Play / Pause
            GestureDetector(
              onTap: onTogglePlayback,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: iconColor.withValues(alpha: 0.5),
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

            // Next
            IconButton(
              icon: const Icon(FontAwesomeIcons.arrowRotateRight),
              iconSize: 28,
              color: iconColor.withValues(alpha: 0.7),
              onPressed: onPlayContinuous,
              tooltip: "Next Sentence",
            ),
          ],
        ),

        // --- FLASHCARD CONTENT ---
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragEnd: (details) {
              // Swipe LEFT to go NEXT
              if (details.primaryVelocity! < 0) {
                onNext();
              }
              // Swipe RIGHT to go PREV
              else if (details.primaryVelocity! > 0) {
                onPrev();
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              alignment: Alignment.center,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    InteractiveTextDisplay(
                      text: currentText,
                      sentenceIndex: safeIndex,
                      vocabulary: vocabulary,
                      language: language, // <--- CORRECTLY PASSED
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
    final bool hasTranslation =
        googleTranslation != null || myMemoryTranslation != null;

    if (isLoadingTranslation) {
      return const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (!hasTranslation && showError) {
      return TextButton(
        onPressed: onRetryTranslation,
        child: const Text("Retry Translation"),
      );
    } else {
      return Column(
        children: [
          if (myMemoryTranslation != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                myMemoryTranslation!,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          if (googleTranslation != null)
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: Text(
                "$googleTranslation",
                style: TextStyle(
                  color: Colors.grey[400],
                  fontStyle: FontStyle.italic,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(height: 12),
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

// --- PARAGRAPH MODE (List/Book Style) ---
class ParagraphModeView extends StatelessWidget {
  final LessonModel lesson;
  final List<List<int>> bookPages;
  final int activeSentenceIndex;
  final int currentPage;
  final Map<String, VocabularyItem> vocabulary;
  final bool isVideo;
  final ScrollController listScrollController;
  final PageController pageController;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onSentenceTap;
  final ValueChanged<double> onVideoSeek;
  final Function(String, String, Offset) onWordTap;
  final Function(String phrase, Offset pos, VoidCallback clearSelection)
  onPhraseSelected;
  final bool isListeningMode;
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
    required this.itemKeys,
    this.isListeningMode = false,
  });

  @override
  Widget build(BuildContext context) {
    // 1. TRANSCRIPT VIEW (Scrolling List)
    // Used if we have parsed transcript data (always true for fixed local import now)
    if (lesson.transcript.isNotEmpty) {
      return ListView.separated(
        controller: listScrollController,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        itemCount: lesson.transcript.length + 1, // +1 for bottom padding
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == lesson.transcript.length) {
            return const SizedBox(height: 100);
          }

          final entry = lesson.transcript[index];
          final bool isActive = index == activeSentenceIndex;

          return _buildTranscriptRow(
            context,
            index,
            entry.text,
            entry.start,
            isActive,
          );
        },
      );
    }

    // 2. BOOK VIEW (Pages)
    // Fallback for text-only content
    if (bookPages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

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
              ...bookPages[pageIndex].map(
                (idx) => _buildBookRow(
                  context,
                  idx,
                  lesson.sentences[idx],
                  idx == activeSentenceIndex,
                ),
              ),
              const SizedBox(height: 100),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTranscriptRow(
    BuildContext context,
    int index,
    String text,
    double start,
    bool isActive,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Safety check for keys
    final Key? rowKey = (index < itemKeys.length) ? itemKeys[index] : null;

    return Container(
      key: rowKey, // Essential for Auto-Scroll
      margin: const EdgeInsets.only(bottom: 12),
      padding: isActive
          ? const EdgeInsets.all(12)
          : const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: isActive
            ? (isDark
                  ? Colors.blue.withValues(alpha: 0.2)
                  : Colors.blue.withValues(alpha: 0.1))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: isActive
            ? Border.all(color: Colors.blue.withValues(alpha: 0.3))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Play Button for this specific line
          if (isVideo)
            GestureDetector(
              onTap: () => onVideoSeek(start),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(top: 2, right: 12, left: 4),
                child: Icon(
                  isActive ? Icons.play_arrow : Icons.play_arrow_outlined,
                  color: isActive ? Colors.blue : Colors.grey[400],
                  size: 26,
                ),
              ),
            ),

          Expanded(
            child: InteractiveTextDisplay(
              language: lesson.language, // <--- CORRECTLY PASSED
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

  Widget _buildBookRow(
    BuildContext context,
    int index,
    String text,
    bool isActive,
  ) {
    // Safety check for keys
    final Key? rowKey = (index < itemKeys.length) ? itemKeys[index] : null;

    return GestureDetector(
      onDoubleTap: () => onSentenceTap(index),
      child: Container(
        key: rowKey,
        margin: const EdgeInsets.only(bottom: 24),
        padding: isActive ? const EdgeInsets.all(12) : EdgeInsets.zero,
        decoration: BoxDecoration(
          color: isActive
              ? Colors.yellow.withValues(alpha: 0.3)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: InteractiveTextDisplay(
          language: lesson.language, // <--- CORRECTLY PASSED
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
