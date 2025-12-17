import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/models/vocabulary_item.dart';
import 'package:linguaflow/screens/home/widgets/lesson_cards.dart';
import 'package:linguaflow/screens/reader/reader_screen.dart';
import 'package:linguaflow/screens/home/widgets/home_dialogs.dart';
import 'package:linguaflow/services/repositories/lesson_repository.dart';
import 'package:linguaflow/utils/utils.dart'; // For printLog

// ==============================================================================
// HELPER: Deduplicate Series (Group Playlist Videos)
// ==============================================================================

// ==============================================================================
// HELPER: Show Playlist Bottom Sheet (FIXED LAYOUT)
// ==============================================================================

// ==============================================================================
// 1. GUIDED COURSES SECTION
// ==============================================================================
class GuidedCoursesSection extends StatefulWidget {
  final List<LessonModel> guidedLessons;
  final List<LessonModel> importedLessons;
  final Map<String, VocabularyItem> vocabMap;
  final bool isDark;
  final String languageCode;

  const GuidedCoursesSection({
    super.key,
    required this.guidedLessons,
    required this.importedLessons,
    required this.vocabMap,
    required this.isDark,
    required this.languageCode,
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
    if (_guidedTab == 'Imported') return;
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
      final lastLesson = _allGuidedLessons.lastWhere(
        (l) => !l.isLocal,
        orElse: () => _allGuidedLessons.last,
      );
      final newLessons = await repo.fetchPagedCategory(
        widget.languageCode,
        'standard',
        lastLesson: lastLesson,
        limit: 10,
      );
      if (newLessons.isEmpty) {
        setState(() => _hasReachedMax = true);
      } else {
        setState(() => _allGuidedLessons.addAll(newLessons));
      }
    } catch (e) {
      printLog("Error loading guided: $e");
    } finally {
      setState(() => _isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    List<LessonModel> rawLessons = [];
    if (_guidedTab == 'Imported') {
      rawLessons = widget.importedLessons;
    } else {
      final nonImported = _allGuidedLessons.where(
        (l) => !widget.importedLessons.contains(l),
      );
      if (_guidedTab == 'All') {
        rawLessons = nonImported.toList();
      } else {
        rawLessons = nonImported
            .where(
              (l) => l.difficulty.toLowerCase() == _guidedTab.toLowerCase(),
            )
            .toList();
      }
    }

    final displayLessons = deduplicateSeries(rawLessons);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 0, 8),
          child: Text(
            "Guided Courses",
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
            children: _guidedTabsList.map((tab) => _buildTab(tab)).toList(),
          ),
        ),
        if (displayLessons.isEmpty && !_isLoadingMore)
          Container(
            height: 240,
            alignment: Alignment.center,
            child: const Text(
              "No courses found.",
              style: TextStyle(color: Colors.grey),
            ),
          )
        else
          SizedBox(
            height: 240,
            child: ListView.separated(
              controller: _guidedTab == 'Imported' ? null : _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
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
                final lesson = displayLessons[index];
                final bool isSeries =
                    lesson.seriesId != null && lesson.seriesId!.isNotEmpty;

                return VideoLessonCard(
                  lesson: lesson,
                  vocabMap: widget.vocabMap,
                  isDark: widget.isDark,
                  // Update this logic:
                  onTap: () {
                    if (isSeries) {
                      showPlaylistBottomSheet(
                        context,
                        lesson,
                        rawLessons,
                        widget.isDark,
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ReaderScreen(lesson: lesson),
                        ),
                      );
                    }
                  },
                  onOptionTap: () {
                    showLessonOptions(context, lesson, widget.isDark);
                  },
                  onPlaylistTap: isSeries
                      ? () {
                          showPlaylistBottomSheet(
                            context,
                            lesson,
                            rawLessons,
                            widget.isDark,
                          );
                        }
                      : null,
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
// 2. IMMERSION SECTION
// ==============================================================================
class ImmersionSection extends StatefulWidget {
  final List<LessonModel> lessons;
  final Map<String, VocabularyItem> vocabMap;
  final bool isDark;
  final String languageCode;

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
  String _tab = 'All';
  final List<String> _tabs = ['All', 'Beginner', 'Intermediate', 'Advanced'];
  late List<LessonModel> _lessons;
  final ScrollController _scrollController = ScrollController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _lessons = List.from(widget.lessons);
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_loading) {
        _loadMore();
      }
    });
  }

  Future<void> _loadMore() async {
    setState(() => _loading = true);
    try {
      final newItems = await context
          .read<LessonRepository>()
          .fetchPagedCategory(
            widget.languageCode,
            'video',
            lastLesson: _lessons.last,
            limit: 10,
          );
      if (newItems.isNotEmpty) setState(() => _lessons.addAll(newItems));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rawlessons = _tab == 'All'
        ? _lessons
        : _lessons
              .where((l) => l.difficulty.toLowerCase() == _tab.toLowerCase())
              .toList();
    final displayList = deduplicateSeries(rawlessons);

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
          child: Row(children: _tabs.map((t) => _buildTab(t)).toList()),
        ),
        SizedBox(
          height: 260,
          child: ListView.separated(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: displayList.length + (_loading ? 1 : 0),
            separatorBuilder: (ctx, i) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              if (index >= displayList.length) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              final lesson = displayList[index];

              final bool isSeries =
                  lesson.seriesId != null && lesson.seriesId!.isNotEmpty;

              return VideoLessonCard(
                lesson: lesson,
                vocabMap: widget.vocabMap,
                isDark: widget.isDark,
                onTap: () {
                  if (isSeries) {
                    showPlaylistBottomSheet(
                      context,
                      lesson,
                      rawlessons,
                      widget.isDark,
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ReaderScreen(lesson: lesson),
                      ),
                    );
                  }
                },
                onOptionTap: () {
                  showLessonOptions(context, lesson, widget.isDark);
                },
                onPlaylistTap: isSeries
                    ? () {
                        showPlaylistBottomSheet(
                          context,
                          lesson,
                          rawlessons,
                          widget.isDark,
                        );
                      }
                    : null,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTab(String tab) {
    final isSelected = _tab == tab;
    return Padding(
      padding: const EdgeInsets.only(right: 24.0, bottom: 12),
      child: InkWell(
        onTap: () => setState(() => _tab = tab),
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

class LibrarySection extends StatefulWidget {
  final List<LessonModel> lessons;
  final Map<String, VocabularyItem> vocabMap;
  final bool isDark;
  final String languageCode;

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
  String _tab = 'All';
  final List<String> _tabs = ['All', 'Beginner', 'Intermediate', 'Advanced'];
  late List<LessonModel> _lessons;
  final ScrollController _scrollController = ScrollController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _lessons = List.from(widget.lessons);
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_loading) {
        _loadMore();
      }
    });
  }

  // CRITICAL FIX: Sync data when parent updates
  @override
  void didUpdateWidget(LibrarySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.lessons.length != oldWidget.lessons.length) {
      setState(() {
        _lessons = List.from(widget.lessons);
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final newItems = await context
          .read<LessonRepository>()
          .fetchPagedCategory(
            widget.languageCode,
            'book',
            lastLesson: _lessons.isNotEmpty ? _lessons.last : null,
            limit: 10,
          );
      if (newItems.isNotEmpty) {
        setState(() => _lessons.addAll(newItems));
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Sort
    var sorted = List<LessonModel>.from(_lessons)
      ..sort((a, b) {
        if (a.difficulty == 'beginner' && b.difficulty != 'beginner') return -1;
        if (a.difficulty != 'beginner' && b.difficulty == 'beginner') return 1;
        return 0;
      });

    // 2. Filter
    final rawLessons = _tab == 'All'
        ? sorted
        : sorted
              .where((l) => l.difficulty.toLowerCase() == _tab.toLowerCase())
              .toList();

    // 3. Deduplicate
    final displayList = deduplicateSeries(rawLessons);

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
          child: Row(children: _tabs.map((t) => _buildTab(t)).toList()),
        ),

        // 4. Handle Empty State vs List
        if (displayList.isEmpty && !_loading)
          const SizedBox(
            height: 260,
            child: Center(
              child: Text(
                "No lessons found.",
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          SizedBox(
            height: 260,
            child: ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: displayList.length + (_loading ? 1 : 0),
              separatorBuilder: (ctx, i) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                if (index >= displayList.length) {
                  return const Center(child: CircularProgressIndicator());
                }

                final lesson = displayList[index];
                final bool isSeries =
                    lesson.seriesId != null && lesson.seriesId!.isNotEmpty;

                if (lesson.type == 'text') {
                  return TextLessonCard(
                    lesson: lesson,
                    vocabMap: widget.vocabMap,
                    isDark: widget.isDark,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ReaderScreen(lesson: lesson),
                      ),
                    ),
                    onOptionTap: () =>
                        showLessonOptions(context, lesson, widget.isDark),
                  );
                }

                return VideoLessonCard(
                  lesson: lesson,
                  vocabMap: widget.vocabMap,
                  isDark: widget.isDark,
                  onTap: () {
                    if (isSeries) {
                      showPlaylistBottomSheet(
                        context,
                        lesson,
                        rawLessons,
                        widget.isDark,
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ReaderScreen(lesson: lesson),
                        ),
                      );
                    }
                  },
                  onOptionTap: () =>
                      showLessonOptions(context, lesson, widget.isDark),
                  onPlaylistTap: isSeries
                      ? () => showPlaylistBottomSheet(
                          context,
                          lesson,
                          rawLessons,
                          widget.isDark,
                        )
                      : null,
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildTab(String tab) {
    final isSelected = _tab == tab;
    return Padding(
      padding: const EdgeInsets.only(right: 24.0, bottom: 12),
      child: InkWell(
        onTap: () => setState(() => _tab = tab),
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
