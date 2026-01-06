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
  final String language;

  // --- NEW PARAMS ---
  final VoidCallback onComplete;
  final String lessonTitle;
  final int wordsLearnedCount;
  final int xpEarned;

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
    required this.language,
    required this.onComplete,
    required this.lessonTitle,
    required this.wordsLearnedCount,
    required this.xpEarned,
    this.isListeningMode = false,
  });

  @override
  Widget build(BuildContext context) {
    if (chunks.isEmpty) return const Center(child: Text("No content"));

    final safeIndex = activeIndex.clamp(0, chunks.length - 1);
    final currentText = chunks[safeIndex];
    final bool isLastSentence = safeIndex == chunks.length - 1;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white : Colors.black87;

    // Use ListView to allow scrolling if completion UI is tall
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const SizedBox(height: 20),

        // --- CONTROLS ---
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(FontAwesomeIcons.arrowRotateLeft),
              iconSize: 28,
              color: iconColor.withValues(alpha: 0.7),
              onPressed: onPlayFromStartContinuous,
              tooltip: "Restart Sentence",
            ),
            const SizedBox(width: 24),
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
            IconButton(
              icon: const Icon(FontAwesomeIcons.arrowRotateRight),
              iconSize: 28,
              color: iconColor.withValues(alpha: 0.7),
              onPressed: onPlayContinuous,
              tooltip: "Next Sentence",
            ),
          ],
        ),

        // --- CONTENT ---
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          alignment: Alignment.center,
          child: Column(
            children: [
              InteractiveTextDisplay(
                text: currentText,
                sentenceIndex: safeIndex,
                vocabulary: vocabulary,
                language: language,
                isBigMode: true,
                onWordTap: onWordTap,
                onPhraseSelected: onPhraseSelected,
                isListeningMode: isListeningMode,
              ),
              const SizedBox(height: 24),
              _buildTranslationSection(context),

              // --- COMPLETION UI INLINE ---
              if (isLastSentence) ...[
                const SizedBox(height: 40),
                const Divider(),
                const SizedBox(height: 20),
                CompletionInfoView(
                  lessonTitle: lessonTitle,
                  wordsLearnedCount: wordsLearnedCount,
                  xpEarned: xpEarned,
                  onComplete: onComplete,
                ),
              ],
              const SizedBox(height: 100), // Bottom Padding
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTranslationSection(BuildContext context) {
    // ... (Keep existing implementation) ...
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

  // --- NEW PARAMS ---
  final VoidCallback onComplete;
  final int wordsLearnedCount;
  final int xpEarned;

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
    required this.onComplete,
    required this.wordsLearnedCount,
    required this.xpEarned,
    this.isListeningMode = false,
  });

  @override
  Widget build(BuildContext context) {
    // 1. TRANSCRIPT VIEW (Scrolling List)
    if (lesson.transcript.isNotEmpty) {
      return ListView.separated(
        controller: listScrollController,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        itemCount: lesson.transcript.length + 1,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          // --- LAST ITEM: COMPLETION UI ---
          if (index == lesson.transcript.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: CompletionInfoView(
                lessonTitle: lesson.title,
                wordsLearnedCount: wordsLearnedCount,
                xpEarned: xpEarned,
                onComplete: onComplete,
              ),
            );
          }

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

    // 2. BOOK VIEW (Pages)
    if (bookPages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return PageView.builder(
      controller: pageController,
      itemCount: bookPages.length + 1, // +1 for completion page
      onPageChanged: onPageChanged,
      itemBuilder: (context, pageIndex) {
        // --- COMPLETION PAGE ---
        if (pageIndex == bookPages.length) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: CompletionInfoView(
              lessonTitle: lesson.title,
              wordsLearnedCount: wordsLearnedCount,
              xpEarned: xpEarned,
              onComplete: onComplete,
            ),
          );
        }

        // --- NORMAL PAGE ---
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

  // ... (Keep existing _buildTranscriptRow and _buildBookRow methods exactly as they were) ...
  Widget _buildTranscriptRow(
    BuildContext context,
    int index,
    String text,
    double start,
    bool isActive,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Key? rowKey = (index < itemKeys.length) ? itemKeys[index] : null;

    return Container(
      key: rowKey,
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
              language: lesson.language,
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
          language: lesson.language,
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

// ----------------------------------------------------------------------
// --- NEW REUSABLE WIDGET: COMPLETION INFO VIEW (From your snippets) ---
// ----------------------------------------------------------------------
class CompletionInfoView extends StatelessWidget {
  final String lessonTitle;
  final int wordsLearnedCount;
  final int xpEarned;
  final VoidCallback onComplete;

  const CompletionInfoView({
    super.key,
    required this.lessonTitle,
    required this.wordsLearnedCount,
    required this.xpEarned,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 1. Success Icon
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded, color: Colors.green, size: 64),
        ),
        const SizedBox(height: 32),

        // 2. Title & Message
        Text(
          "Lesson Complete!",
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          lessonTitle,
          style: TextStyle(
            fontSize: 18,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),

        const SizedBox(height: 48),

        // 3. Stats Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.grey[100],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Text(
                "SESSION PERFORMANCE",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatItem(
                    context,
                    count: "1",
                    label: "Lessons",
                    icon: Icons.menu_book_rounded,
                    color: Colors.blue,
                  ),
                  _buildVerticalDivider(isDark),
                  _buildStatItem(
                    context,
                    count: "$wordsLearnedCount",
                    label: "Words",
                    icon: Icons.trending_up_rounded,
                    color: Colors.orange,
                  ),
                  _buildVerticalDivider(isDark),
                  _buildStatItem(
                    context,
                    count: xpEarned.toString(),
                    label: 'XP',
                    icon: Icons.bolt,
                    color: Colors.amber,
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 48),

        // 4. Finish Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onComplete,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 18),
              backgroundColor: Theme.of(context).primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
            ),
            child: const Text(
              "Finish",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required String count,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 12),
        Text(
          count,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalDivider(bool isDark) {
    return Container(
      height: 40,
      width: 1,
      color: isDark ? Colors.white24 : Colors.grey[300],
    );
  }
}
