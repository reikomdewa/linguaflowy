import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart'; // Needed for context.read
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/models/vocabulary_item.dart';
import 'package:linguaflow/screens/reader/reader_screen.dart';
import 'package:linguaflow/screens/quiz/widgets/practice_banner_button.dart';
import 'package:linguaflow/utils/utils.dart';
import 'package:linguaflow/services/repositories/lesson_repository.dart'; // Make sure this path is correct
// Needed for options
import '../lesson_cards.dart';

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
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ReaderScreen(lesson: lesson)),
      );
    },
    onOptionTap: () {
      showLessonOptions(context, lesson, isDark);
    },
  );
}

// ==============================================================================
// 1. GUIDED COURSES (Standard Pagination)
// ==============================================================================
class GuidedCoursesSection extends StatefulWidget {
  final List<LessonModel> guidedLessons;
  final List<LessonModel> importedLessons;
  final Map<String, VocabularyItem> vocabMap;
  final bool isDark;
  // We need language code to fetch more
  final String languageCode;

  const GuidedCoursesSection({
    super.key,
    required this.guidedLessons,
    required this.importedLessons,
    required this.vocabMap,
    required this.isDark,
    required this.languageCode, // Pass this from parent
  });

  @override
  State<GuidedCoursesSection> createState() => _GuidedCoursesSectionState();
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

  // --- PAGINATION STATE ---
  late List<LessonModel> _allGuidedLessons;
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  bool _hasReachedMax = false;

  @override
  void initState() {
    super.initState();
    _allGuidedLessons = List.from(widget.guidedLessons);
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(GuidedCoursesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync if parent updates
    if (widget.guidedLessons.length > oldWidget.guidedLessons.length) {
      _allGuidedLessons = List.from(widget.guidedLessons);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isImportedTab) return; // Don't paginate imported tab
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  bool get _isImportedTab => _guidedTab == 'Imported';

  Future<void> _loadMore() async {
    if (_isLoadingMore || _hasReachedMax) return;

    setState(() => _isLoadingMore = true);

    try {
      // Fetch 'guided' type from repo
      final repo = context.read<LessonRepository>();
      final lastLesson = _allGuidedLessons.lastWhere(
        (l) => !l.isLocal,
        orElse: () => _allGuidedLessons.last,
      );

      final newLessons = await repo.fetchPagedCategory(
        widget.languageCode,
        'standard', // This maps to Guided/Standard in your Repo
        lastLesson: lastLesson,
        limit: 10,
      );

      if (newLessons.isEmpty) {
        setState(() => _hasReachedMax = true);
      } else {
        setState(() {
          _allGuidedLessons.addAll(newLessons);
        });
      }
    } catch (e) {
      printLog("Error loading more guided: $e");
    } finally {
      setState(() => _isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    List<LessonModel> displayLessons = [];

    if (_isImportedTab) {
      displayLessons = widget.importedLessons;
    } else {
      // Filter the _allGuidedLessons list which grows as we scroll
      final nonImportedLessons = _allGuidedLessons.where(
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
        if (displayLessons.isEmpty && !_isLoadingMore)
          Container(
            height: 240,
            alignment: Alignment.center,
            child: Text(
              "No courses found.",
              style: TextStyle(color: Colors.grey),
            ),
          )
        else
          SizedBox(
            height: 240,
            child: ListView.separated(
              controller: _isImportedTab
                  ? null
                  : _scrollController, // Only attach scroll listener if fetching from server
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              // +1 for Spinner if loading
              itemCount: displayLessons.length + (_isLoadingMore ? 1 : 0),
              separatorBuilder: (ctx, i) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                if (index >= displayLessons.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
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

// ==============================================================================
// 2. IMMERSION SECTION (Infinite Video Scroll)
// ==============================================================================
class ImmersionSection extends StatefulWidget {
  final List<LessonModel> lessons;
  final Map<String, VocabularyItem> vocabMap;
  final bool isDark;
  final String languageCode; // Needed for repo call

  const ImmersionSection({
    super.key,
    required this.lessons,
    required this.vocabMap,
    required this.isDark,
    required this.languageCode,
  });

  @override
  State<ImmersionSection> createState() => _ImmersionSectionState();
}

class _ImmersionSectionState extends State<ImmersionSection> {
  String _nativeDifficultyTab = 'All';
  final List<String> _difficultyTabs = [
    'All',
    'Beginner',
    'Intermediate',
    'Advanced',
  ];

  // --- PAGINATION STATE ---
  late List<LessonModel> _immersionLessons;
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  bool _hasReachedMax = false;

  @override
  void initState() {
    super.initState();
    _immersionLessons = List.from(widget.lessons);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || _hasReachedMax) return;

    setState(() => _isLoadingMore = true);

    try {
      final repo = context.read<LessonRepository>();
      final lastLesson = _immersionLessons.last;

      // Call the pagination method specifically for VIDEOS
      final newLessons = await repo.fetchPagedCategory(
        widget.languageCode,
        'video',
        lastLesson: lastLesson,
        limit: 10,
      );

      if (newLessons.isEmpty) {
        setState(() => _hasReachedMax = true);
      } else {
        setState(() {
          _immersionLessons.addAll(newLessons);
        });
      }
    } catch (e) {
      printLog("Error loading videos: $e");
    } finally {
      setState(() => _isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filter the dynamically growing list
    final displayVideos = _nativeDifficultyTab == 'All'
        ? _immersionLessons
        : _immersionLessons
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
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: _difficultyTabs.map((tab) => _buildTab(tab)).toList(),
          ),
        ),
        if (displayVideos.isEmpty && !_isLoadingMore)
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
              controller: _scrollController, // Attached listener
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              // Add +1 for spinner
              itemCount: displayVideos.length + (_isLoadingMore ? 1 : 0),
              separatorBuilder: (ctx, i) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                if (index >= displayVideos.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
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

// ==============================================================================
// 3. LIBRARY SECTION (Infinite Book Scroll)
// ==============================================================================
class LibrarySection extends StatefulWidget {
  final List<LessonModel> lessons;
  final Map<String, VocabularyItem> vocabMap;
  final bool isDark;
  final String languageCode; // Needed for repo

  const LibrarySection({
    super.key,
    required this.lessons,
    required this.vocabMap,
    required this.isDark,
    required this.languageCode,
  });

  @override
  State<LibrarySection> createState() => _LibrarySectionState();
}

class _LibrarySectionState extends State<LibrarySection> {
  String _libraryDifficultyTab = 'All';
  final List<String> _difficultyTabs = [
    'All',
    'Beginner',
    'Intermediate',
    'Advanced',
  ];

  // --- PAGINATION STATE ---
  late List<LessonModel> _libraryLessons;
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  bool _hasReachedMax = false;

  @override
  void initState() {
    super.initState();
    _libraryLessons = List.from(widget.lessons);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || _hasReachedMax) return;

    setState(() => _isLoadingMore = true);

    try {
      final repo = context.read<LessonRepository>();
      final lastLesson = _libraryLessons.last;

      final newLessons = await repo.fetchPagedCategory(
        widget.languageCode,
        'book',
        lastLesson: lastLesson,
        limit: 10,
      );

      if (newLessons.isEmpty) {
        setState(() => _hasReachedMax = true);
      } else {
        setState(() {
          _libraryLessons.addAll(newLessons);
        });
      }
    } catch (e) {
      printLog("Error loading books: $e");
    } finally {
      setState(() => _isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sort logic from original code
    var sortedLessons = List<LessonModel>.from(_libraryLessons);
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
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: _difficultyTabs.map((tab) => _buildTab(tab)).toList(),
          ),
        ),
        if (displayBooks.isEmpty && !_isLoadingMore)
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
              controller: _scrollController, // Attached
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              // +1 for spinner
              itemCount: displayBooks.length + (_isLoadingMore ? 1 : 0),
              separatorBuilder: (ctx, i) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                if (index >= displayBooks.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
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
