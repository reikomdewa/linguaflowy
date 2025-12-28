import 'dart:async'; // Required for TimeoutException
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/models/vocabulary_item.dart';
import 'package:linguaflow/screens/home/widgets/lesson_cards.dart';
import 'package:linguaflow/screens/reader/reader_screen.dart';
import 'package:linguaflow/blocs/vocabulary/vocabulary_bloc.dart';
import 'package:linguaflow/services/repositories/lesson_repository.dart';
import 'package:linguaflow/utils/utils.dart';

class CategoryResultsScreen extends StatefulWidget {
  final String categoryTitle;

  // OPTION A: Pass a static list
  final List<LessonModel>? initialLessons;

  // OPTION B: Pass keys to fetch data
  final String? genreKey;
  final String? languageCode;

  const CategoryResultsScreen({
    super.key,
    required this.categoryTitle,
    this.initialLessons,
    this.genreKey,
    this.languageCode,
  });

  @override
  State<CategoryResultsScreen> createState() => _CategoryResultsScreenState();
}

class _CategoryResultsScreenState extends State<CategoryResultsScreen> {
  late List<LessonModel> _lessons;
  final ScrollController _scrollController = ScrollController();

  bool _isDynamicMode = false;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasReachedMax = false;

  // CONSTANT: How many items to fetch per page
  static const int _pageSize = 15;

  @override
  void initState() {
    super.initState();

    if (widget.initialLessons != null && widget.initialLessons!.isNotEmpty) {
      _lessons = List.from(widget.initialLessons!);
      _isDynamicMode = false;
    } else {
      _lessons = [];
      _isDynamicMode = true;
      _loadInitialData();
    }

    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_isDynamicMode) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadInitialData() async {
    if (widget.genreKey == null || widget.languageCode == null) return;

    setState(() => _isLoading = true);
    try {
      final repo = context.read<LessonRepository>();

      // Add Timeout to prevent infinite loading screen
      final results = await repo
          .fetchPagedGenreLessons(
            widget.languageCode!,
            widget.genreKey!,
            limit: _pageSize,
          )
          .timeout(const Duration(seconds: 10));

      if (mounted) {
        setState(() {
          _lessons = results;
          // If we got fewer items than requested, we are already at the end
          if (results.length < _pageSize) {
            _hasReachedMax = true;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    // 1. Guard clauses
    if (_isLoadingMore || _hasReachedMax || _lessons.isEmpty) return;

    setState(() => _isLoadingMore = true);

    try {
      final repo = context.read<LessonRepository>();
      final lastLesson = _lessons.last;

      // 2. Fetch with Timeout
      final newLessons = await repo
          .fetchPagedGenreLessons(
            widget.languageCode!,
            widget.genreKey!,
            lastLesson: lastLesson,
            limit: _pageSize,
          )
          .timeout(const Duration(seconds: 10)); // Force stop after 10s

      if (mounted) {
        setState(() {
          if (newLessons.isEmpty) {
            _hasReachedMax = true;
          } else {
            // Deduplicate logic
            final existingIds = _lessons.map((l) => l.id).toSet();
            final uniqueNew = newLessons
                .where((l) => !existingIds.contains(l.id))
                .toList();

            if (uniqueNew.isEmpty) {
              // If we fetched items but they were all duplicates, we are effectively done
              _hasReachedMax = true;
            } else {
              _lessons.addAll(uniqueNew);

              // 3. Smart Limit Check
              // If we asked for 15 and got fewer, we know there is no more data.
              if (newLessons.length < _pageSize) {
                _hasReachedMax = true;
              }
            }
          }
        });
      }
    } catch (e) {
      // On error or timeout, we simply stop the spinner so the user can try again later
      printLog("Load more failed or timed out: $e");
    } finally {
      // 4. Always ensure the spinner turns off
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // RESPONSIVE CHECK: Desktop/Tablet vs Mobile
    final width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 900;
    final bool isTablet = width > 600 && width <= 900;

    final vocabState = context.watch<VocabularyBloc>().state;
    Map<String, VocabularyItem> vocabMap = {};
    if (vocabState is VocabularyLoaded) {
      vocabMap = {
        for (var item in vocabState.items) item.word.toLowerCase(): item,
      };
    }

    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: Text(widget.categoryTitle),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _lessons.isEmpty
          ? Center(
              child: Text(
                "No videos found for ${widget.categoryTitle}",
                style: const TextStyle(color: Colors.grey),
              ),
            )
          : Center(
              // Limits max width on huge screens for better aesthetics
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Scrollbar(
                  // Adds a scrollbar for desktop users
                  controller: _scrollController,
                  thumbVisibility: isDesktop,
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.all(16),
                        // RESPONSIVE LOGIC: Switch between List and Grid
                        sliver: isDesktop || isTablet
                            ? _buildDesktopGrid(vocabMap, isDark, width)
                            : _buildMobileList(vocabMap, isDark),
                      ),

                      // Bottom Loader
                      SliverToBoxAdapter(child: _buildBottomLoader()),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  // --- MOBILE LAYOUT (List) ---
  Widget _buildMobileList(Map<String, VocabularyItem> vocabMap, bool isDark) {
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final lesson = _lessons[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: VideoLessonCard(
            lesson: lesson,
            vocabMap: vocabMap,
            isDark: isDark,
            onTap: () => _navigateToReader(lesson),
            onOptionTap: () => showLessonOptions(context, lesson, isDark),
          ),
        );
      }, childCount: _lessons.length),
    );
  }

  // --- DESKTOP/WEB LAYOUT (Grid) ---
  Widget _buildDesktopGrid(
    Map<String, VocabularyItem> vocabMap,
    bool isDark,
    double width,
  ) {
    // Calculate columns: 2 for tablet, 3 or 4 for desktop
    int crossAxisCount = width > 1100 ? 4 : (width > 900 ? 3 : 2);

    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85, // Taller ratio for cards on grid
      ),
      delegate: SliverChildBuilderDelegate((context, index) {
        final lesson = _lessons[index];
        return VideoLessonCard(
          lesson: lesson,
          vocabMap: vocabMap,
          isDark: isDark,
          onTap: () => _navigateToReader(lesson),
          onOptionTap: () => showLessonOptions(context, lesson, isDark),
        );
      }, childCount: _lessons.length),
    );
  }

  Widget _buildBottomLoader() {
    if (_hasReachedMax || !_isDynamicMode) {
      return const SizedBox(height: 40); // Spacer at bottom
    }
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24.0),
        child: CircularProgressIndicator(),
      ),
    );
  }

  void _navigateToReader(LessonModel lesson) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ReaderScreen(lesson: lesson)),
    );
  }
}
