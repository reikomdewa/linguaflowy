import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/models/vocabulary_item.dart';
import 'package:linguaflow/screens/home/widgets/lesson_cards.dart';
import 'package:linguaflow/screens/quiz/widgets/practice_banner_button.dart';
import 'package:linguaflow/screens/reader/reader_screen.dart';
import 'package:linguaflow/screens/reader/reader_screen_web.dart';
import 'package:linguaflow/services/repositories/lesson_repository.dart';
import 'package:linguaflow/utils/utils.dart';

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
      _hasReachedMax = false; // Reset on refresh
    }
  }

  void _onScroll() {
    if (_guidedTab == 'Imported' || _isLoadingMore || _hasReachedMax) return;
    // Trigger much earlier (500px from end) to make it feel smoother
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 500) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || _hasReachedMax) return;
    setState(() => _isLoadingMore = true);

    try {
      final repo = context.read<LessonRepository>();

      // 🔥 FIND THE LAST CLOUD LESSON (ID starting with yt_)
      // This is the cursor Firestore uses to know where the "next page" is.
      final cloudLessons = _allGuidedLessons
          .where((l) => l.id.startsWith('yt_'))
          .toList();
      final lastLesson = cloudLessons.isNotEmpty ? cloudLessons.last : null;

      final newLessons = await repo.fetchPagedCategory(
        widget.languageCode,
        'guided',
        lastLesson: lastLesson,
        limit: 30, // 🔥 INCREASED LIMIT: Higher chance to get unique cards
      );

      if (newLessons.isEmpty) {
        if (mounted) setState(() => _hasReachedMax = true);
      } else {
        if (mounted) {
          setState(() {
            final existingIds = _allGuidedLessons.map((l) => l.id).toSet();
            final uniqueNew = newLessons
                .where((l) => !existingIds.contains(l.id))
                .toList();

            _allGuidedLessons.addAll(uniqueNew);

            // 🔥 CRITICAL FIX:
            // If we got items from Firebase but they were already in our list,
            // don't set _hasReachedMax = true. Instead, we allow the user
            // to scroll slightly more to trigger another fetch, OR we
            // could recursively call _loadMore() here.
          });
        }
      }
    } catch (e) {
      print("Error loading: $e");
    } finally {
      // Delay prevents the scroll listener from double-firing too fast
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) setState(() => _isLoadingMore = false);
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth > 800;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                isDesktop ? SizedBox.shrink() : PracticeBannerButton(),
              ],
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: _guidedTabsList.map((t) => _buildTab(t)).toList(),
              ),
            ),
            SizedBox(
              height: 240,
              child: ListView.separated(
                controller: _guidedTab == 'Imported' ? null : _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: displayLessons.length + (_isLoadingMore ? 1 : 0),
                separatorBuilder: (ctx, i) => const SizedBox(width: 16),
                itemBuilder: (context, index) {
                  if (index >= displayLessons.length)
                    return const Center(child: CircularProgressIndicator());
                  final lesson = displayLessons[index];
                  final bool isSeries =
                      lesson.seriesId != null && lesson.seriesId!.isNotEmpty;
                  return VideoLessonCard(
                    lesson: lesson,
                    vocabMap: widget.vocabMap,
                    isDark: widget.isDark,
                    onTap: () => isSeries
                        ? showPlaylistBottomSheet(
                            context,
                            lesson,
                            rawLessons,
                            widget.isDark,
                          )
                        : Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  kIsWeb? ReaderScreenWeb(lesson: lesson) :  ReaderScreen(lesson: lesson),
                            ),
                          ),
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
      },
    );
  }

  Widget _buildTab(String tab) {
    final isSelected = _guidedTab == tab;
    return Padding(
      padding: const EdgeInsets.only(right: 12.0, bottom: 12),
      child: InkWell(
        onTap: () => setState(() {
          _guidedTab = tab;
          _hasReachedMax = false;
        }),
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
  late List<LessonModel> _lessons;
  final ScrollController _scrollController = ScrollController();
  bool _loading = false;
  bool _hasReachedMax = false;

  @override
  void initState() {
    super.initState();
    _lessons = List.from(widget.lessons);
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_loading || _hasReachedMax) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 500) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loading = true);
    try {
      final repo = context.read<LessonRepository>();
      final cloudLessons = _lessons
          .where((l) => l.id.startsWith('yt_'))
          .toList();
      final lastLesson = cloudLessons.isNotEmpty ? cloudLessons.last : null;

      final newItems = await repo.fetchPagedCategory(
        widget.languageCode,
        'video',
        lastLesson: lastLesson,
        limit: 30,
      );

      if (newItems.isEmpty) {
        _hasReachedMax = true;
      } else {
        setState(() {
          final existingIds = _lessons.map((l) => l.id).toSet();
          final unique = newItems
              .where((l) => !existingIds.contains(l.id))
              .toList();
          _lessons.addAll(unique);
        });
      }
    } finally {
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final raw = _tab == 'All'
        ? _lessons
        : _lessons
              .where((l) => l.difficulty.toLowerCase() == _tab.toLowerCase())
              .toList();
    final display = deduplicateSeries(raw);

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
        SizedBox(
          height: 260,
          child: ListView.separated(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: display.length + (_loading ? 1 : 0),
            separatorBuilder: (ctx, i) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              if (index >= display.length)
                return const Center(child: CircularProgressIndicator());
              final l = display[index];
              return VideoLessonCard(
                lesson: l,
                vocabMap: widget.vocabMap,
                isDark: widget.isDark,
                onTap: () => (l.seriesId != null && l.seriesId!.isNotEmpty)
                    ? showPlaylistBottomSheet(context, l, raw, widget.isDark)
                    : Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (c) => kIsWeb? ReaderScreenWeb(lesson: l) : ReaderScreen(lesson: l),
                        ),
                      ),
                onOptionTap: () => showLessonOptions(context, l, widget.isDark),
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
        onTap: () => setState(() {
          _tab = tab;
          _hasReachedMax = false;
        }),
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
