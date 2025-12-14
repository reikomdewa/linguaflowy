import 'package:flutter/material.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/models/vocabulary_item.dart';
import 'package:linguaflow/screens/reader/reader_screen.dart'; // Needed for nav
import 'package:linguaflow/screens/quiz/widgets/practice_banner_button.dart';
import 'package:linguaflow/utils/utils.dart';
import 'home_dialogs.dart'; // Needed for options
import 'lesson_cards.dart';

// --- HELPER METHOD TO BUILD CARDS (DRY Principle) ---
Widget _buildCard(
  BuildContext context,
  LessonModel lesson,
  Map<String, VocabularyItem> vocabMap,
  bool isDark,
) {
  return VideoLessonCard(
    lesson: lesson,
    vocabMap: vocabMap,
    isDark: isDark,
    // Fix: Providing the required arguments
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ReaderScreen(lesson: lesson)),
      );
    },
    onOptionTap: () {
      showLessonOptions(context, lesson, isDark,);
    },
  );
}

// --- GUIDED COURSES ---
class GuidedCoursesSection extends StatefulWidget {
  // ... (Constructor same as before) ...
  final List<LessonModel> guidedLessons;
  final List<LessonModel> importedLessons;
  final Map<String, VocabularyItem> vocabMap;
  final bool isDark;

  const GuidedCoursesSection({
    super.key,
    required this.guidedLessons,
    required this.importedLessons,
    required this.vocabMap,
    required this.isDark,
  });

  @override
  _GuidedCoursesSectionState createState() => _GuidedCoursesSectionState();
}

class _GuidedCoursesSectionState extends State<GuidedCoursesSection> {
  String _guidedTab = 'All';
  final List<String> _guidedTabsList = [
    'All',
    'Beginner',
    'Intermediate',
    'Advanced',
    'Imported',
  ];

  @override
  Widget build(BuildContext context) {
    List<LessonModel> displayLessons = [];

    // --- UPDATED LOGIC START ---
    if (_guidedTab == 'Imported') {
      // 1. If 'Imported' tab is selected, ONLY show imported lessons
      displayLessons = widget.importedLessons;
    } else {
      // 2. For 'All', 'Beginner', etc., start by excluding imported lessons
      //    from the main list to ensure they ONLY appear in the Imported tab.
      final nonImportedLessons = widget.guidedLessons.where(
        (l) => !widget.importedLessons.contains(l),
      );

      if (_guidedTab == 'All') {
        displayLessons = nonImportedLessons.toList();
      } else {
        displayLessons = nonImportedLessons
            .where(
              (l) => l.difficulty.toLowerCase() == _guidedTab.toLowerCase(),
            )
            .toList();
      }
    }
    // --- UPDATED LOGIC END ---

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 0, 8),
          child: Row(
            children: [
              Text(
                "Guided Courses",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: widget.isDark ? Colors.white70 : Colors.black45,
                ),
              ),
              const Expanded(child: PracticeBannerButton()),
            ],
          ),
        ),

        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: _guidedTabsList.map((tab) => _buildTab(tab)).toList(),
          ),
        ),

        // LIST
        if (displayLessons.isEmpty)
          Container(
            height: 260,
            alignment: Alignment.center,
            child: Text(
              _guidedTab == 'Imported'
                  ? "No imported lessons yet."
                  : "No guided courses found.",
              style: const TextStyle(color: Colors.grey),
            ),
          )
        else
          SizedBox(
            height: 240,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: displayLessons.length,
              separatorBuilder: (ctx, i) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                return _buildCard(
                  context,
                  displayLessons[index],
                  widget.vocabMap,
                  widget.isDark,
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildTab(String tab) {
    final isSelected = _guidedTab == tab;
    return Padding(
      padding: const EdgeInsets.only(right: 12.0, bottom: 12),
      child: InkWell(
        onTap: () => setState(() => _guidedTab = tab),
        child: Column(
          children: [
            Text(
              tab,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? (widget.isDark ? Colors.white : Colors.black)
                    : Colors.grey[500],
              ),
            ),
            if (isSelected)
              Container(
                margin: const EdgeInsets.only(top: 4),
                height: 2,
                width: 20,
                color: Colors.blue,
              ),
          ],
        ),
      ),
    );
  }
}

// --- IMMERSION SECTION ---
class ImmersionSection extends StatefulWidget {
  // ... Same Constructor ...
  final List<LessonModel> lessons;
  final Map<String, VocabularyItem> vocabMap;
  final bool isDark;
  const ImmersionSection({
    super.key,
    required this.lessons,
    required this.vocabMap,
    required this.isDark,
  });

  @override
  _ImmersionSectionState createState() => _ImmersionSectionState();
}

class _ImmersionSectionState extends State<ImmersionSection> {
  String _nativeDifficultyTab = 'All';
  final List<String> _difficultyTabs = [
    'All',
    'Beginner',
    'Intermediate',
    'Advanced',
  ];

  @override
  Widget build(BuildContext context) {
    // ... Logic ...
    final displayVideos = _nativeDifficultyTab == 'All'
        ? widget.lessons
        : widget.lessons
              .where(
                (l) =>
                    l.difficulty.toLowerCase() ==
                    _nativeDifficultyTab.toLowerCase(),
              )
              .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            "Immersion",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: widget.isDark ? Colors.white70 : Colors.black45,
            ),
          ),
        ),
        // ... Tabs ...
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: _difficultyTabs.map((tab) => _buildTab(tab)).toList(),
          ),
        ),
        if (displayVideos.isEmpty)
          Container(
            height: 150,
            alignment: Alignment.center,
            child: const Text(
              "No videos found",
              style: TextStyle(color: Colors.grey),
            ),
          )
        else
          SizedBox(
            height: 260,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: displayVideos.length,
              separatorBuilder: (ctx, i) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                // CALL HELPER HERE
                return _buildCard(
                  context,
                  displayVideos[index],
                  widget.vocabMap,
                  widget.isDark,
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildTab(String tab) {
    final isSelected = _nativeDifficultyTab == tab;
    return Padding(
      padding: const EdgeInsets.only(right: 24.0, bottom: 12),
      child: InkWell(
        onTap: () => setState(() => _nativeDifficultyTab = tab),
        child: Column(
          children: [
            Text(
              tab,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? (widget.isDark ? Colors.white : Colors.black)
                    : Colors.grey[500],
              ),
            ),
            if (isSelected)
              Container(
                margin: const EdgeInsets.only(top: 4),
                height: 2,
                width: 20,
                color: Colors.red,
              ),
          ],
        ),
      ),
    );
  }
}

// --- LIBRARY SECTION ---
class LibrarySection extends StatefulWidget {
  // ... Same Constructor ...
  final List<LessonModel> lessons;
  final Map<String, VocabularyItem> vocabMap;
  final bool isDark;
  const LibrarySection({
    super.key,
    required this.lessons,
    required this.vocabMap,
    required this.isDark,
  });

  @override
  _LibrarySectionState createState() => _LibrarySectionState();
}

class _LibrarySectionState extends State<LibrarySection> {
  String _libraryDifficultyTab = 'All';
  final List<String> _difficultyTabs = [
    'All',
    'Beginner',
    'Intermediate',
    'Advanced',
  ];

  @override
  Widget build(BuildContext context) {
    // ... Logic ...
    var sortedLessons = List<LessonModel>.from(widget.lessons);
    sortedLessons.sort((a, b) {
      if (a.difficulty == 'beginner' && b.difficulty != 'beginner') return -1;
      if (a.difficulty != 'beginner' && b.difficulty == 'beginner') return 1;
      return 0;
    });
    final displayBooks = _libraryDifficultyTab == 'All'
        ? sortedLessons
        : sortedLessons
              .where(
                (l) =>
                    l.difficulty.toLowerCase() ==
                    _libraryDifficultyTab.toLowerCase(),
              )
              .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            "Reading Library",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: widget.isDark ? Colors.white70 : Colors.black45,
            ),
          ),
        ),
        // ... Tabs ...
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: _difficultyTabs.map((tab) => _buildTab(tab)).toList(),
          ),
        ),
        if (displayBooks.isEmpty)
          Container(
            height: 150,
            alignment: Alignment.center,
            child: const Text(
              "No books found",
              style: TextStyle(color: Colors.grey),
            ),
          )
        else
          SizedBox(
            height: 260,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: displayBooks.length,
              separatorBuilder: (ctx, i) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                // CALL HELPER HERE
                return _buildCard(
                  context,
                  displayBooks[index],
                  widget.vocabMap,
                  widget.isDark,
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildTab(String tab) {
    final isSelected = _libraryDifficultyTab == tab;
    return Padding(
      padding: const EdgeInsets.only(right: 24.0, bottom: 12),
      child: InkWell(
        onTap: () => setState(() => _libraryDifficultyTab = tab),
        child: Column(
          children: [
            Text(
              tab,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? (widget.isDark ? Colors.white : Colors.black)
                    : Colors.grey[500],
              ),
            ),
            if (isSelected)
              Container(
                margin: const EdgeInsets.only(top: 4),
                height: 2,
                width: 20,
                color: Colors.green,
              ),
          ],
        ),
      ),
    );
  }
}
