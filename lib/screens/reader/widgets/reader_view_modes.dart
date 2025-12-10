import 'package:flutter/material.dart';
import 'package:linguaflow/models/vocabulary_item.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'interactive_text_display.dart';

class SentenceModeView extends StatelessWidget {
  final List<String> chunks;
  final int activeIndex;
  final Map<String, VocabularyItem> vocabulary;
  final bool isVideo;
  final bool isPlaying;
  final bool isTtsPlaying;
  final Function() onTogglePlayback;
  final Function() onNext;
  final Function() onPrev;
  final Function(String, String, Offset) onWordTap;
  final Function(String, Offset) onPhraseSelected; // New Callback
  
  // Translation State Variables
  final bool isLoadingTranslation;
  final String? googleTranslation;
  final String? myMemoryTranslation;
  final bool showError;
  final Function() onRetryTranslation;
  final Function() onTranslateRequest;

  const SentenceModeView({
    super.key,
    required this.chunks,
    required this.activeIndex,
    required this.vocabulary,
    required this.isVideo,
    required this.isPlaying,
    required this.isTtsPlaying,
    required this.onTogglePlayback,
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
  });

  @override
  Widget build(BuildContext context) {
    if (chunks.isEmpty) return const Center(child: Text("No content"));
    final safeIndex = activeIndex.clamp(0, chunks.length - 1);
    final currentText = chunks[safeIndex];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        const SizedBox(height: 40),
        // Play Button
        Center(
          child: GestureDetector(
            onTap: onTogglePlayback,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: (isDark ? Colors.white : Colors.black).withOpacity(0.5), width: 2),
              ),
              child: Icon(
                isVideo
                    ? (isPlaying ? Icons.pause : Icons.play_arrow)
                    : (isTtsPlaying ? Icons.stop : Icons.play_arrow),
                size: 40,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ),
        const Spacer(),
        
        // Swipeable Text Area
        Expanded(
          flex: 3,
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
                    ),
                    const SizedBox(height: 24),
                    _buildTranslationSection(),
                  ],
                ),
              ),
            ),
          ),
        ),
        const Spacer(),
        const Padding(
          padding: EdgeInsets.only(bottom: 20),
          child: Text(
            "Swipe LEFT for next • RIGHT for previous",
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildTranslationSection() {
    if (isLoadingTranslation) {
      return const SizedBox(
          height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2));
    } else if (googleTranslation == null && myMemoryTranslation == null) {
      return showError
          ? Column(
              children: [
                Text("Translation unavailable",
                    style: TextStyle(color: Colors.red[300], fontSize: 13, fontStyle: FontStyle.italic)),
                TextButton(onPressed: onRetryTranslation, child: const Text("Retry"))
              ],
            )
          : TextButton.icon(
              icon: const Icon(Icons.translate, size: 16, color: Colors.grey),
              label: const Text("Translate Sentence", style: TextStyle(color: Colors.grey)),
              onPressed: onTranslateRequest,
            );
    } else {
      return Column(
        children: [
          if (myMemoryTranslation != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                myMemoryTranslation!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic, fontSize: 16),
              ),
            ),
          if (googleTranslation != null)
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: Text(
                "[Google] $googleTranslation",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[400], fontStyle: FontStyle.italic, fontSize: 14),
              ),
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
  final Function(String, Offset) onPhraseSelected;

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
  });

  @override
  Widget build(BuildContext context) {
    // 1. Transcript Mode (Video/Audio)
    if (lesson.transcript.isNotEmpty) {
      return ListView.separated(
        controller: listScrollController,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        itemCount: lesson.transcript.length + 1,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == lesson.transcript.length) return const SizedBox(height: 100);
          final entry = lesson.transcript[index];
          final isActive = index == activeSentenceIndex;
          
          return _buildTranscriptRow(context, index, entry.text, entry.start, isActive);
        },
      );
    }

    // 2. Book Mode (Pagination)
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
              ...bookPages[pageIndex].map((idx) {
                final isActive = idx == activeSentenceIndex;
                return _buildBookRow(context, idx, lesson.sentences[idx], isActive);
              }),
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
        ),
      ),
    );
  }
}