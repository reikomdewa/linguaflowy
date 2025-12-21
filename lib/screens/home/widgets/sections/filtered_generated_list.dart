import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/models/vocabulary_item.dart';
import 'package:linguaflow/screens/home/widgets/lesson_cards.dart';
import 'package:linguaflow/screens/reader/reader_screen.dart';
import 'package:linguaflow/services/repositories/lesson_repository.dart';
import 'package:linguaflow/utils/utils.dart';

class FilteredGenreList extends StatefulWidget {
  final String genreKey;
  final String languageCode;
  final Map<String, VocabularyItem> vocabMap;
  final bool isDark;
  final bool isDesktop;
  final String sortOrder;
  final String filterDifficulty; // <--- 1. ADD THIS

  const FilteredGenreList({
    super.key,
    required this.genreKey,
    required this.languageCode,
    required this.vocabMap,
    required this.isDark,
    required this.isDesktop,
    required this.sortOrder,
    required this.filterDifficulty, // <--- 1. ADD THIS
  });

  @override
  State<FilteredGenreList> createState() => _FilteredGenreListState();
}

class _FilteredGenreListState extends State<FilteredGenreList> {
  final ScrollController _scrollController = ScrollController();
  List<LessonModel> _allFetchedLessons = []; // Rename this to be clear
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasReachedMax = false;

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant FilteredGenreList oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // If Genre changes, we must fetch new data
    if (oldWidget.genreKey != widget.genreKey) {
      _allFetchedLessons.clear();
      _hasReachedMax = false;
      _isLoading = true;
      setState(() {});
      _loadInitial();
    } 
    // If Sort or Difficulty changes, just update the UI (setState)
    else if (oldWidget.sortOrder != widget.sortOrder || 
             oldWidget.filterDifficulty != widget.filterDifficulty) {
      setState(() {}); // Trigger rebuild to apply new filters/sort
    }
  }

  // --- 2. GETTER TO APPLY LOCAL FILTER & SORT ---
  List<LessonModel> get _displayedLessons {
    // A. Filter by Difficulty
    var filtered = _allFetchedLessons.where((l) {
      if (widget.filterDifficulty == 'All') return true;
      return l.difficulty.toLowerCase() == widget.filterDifficulty.toLowerCase();
    }).toList();

    // B. Apply Sort
    if (widget.sortOrder == 'Newest') {
      filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } else {
      filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }

    return filtered;
  }

  // ... dispose ...
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

  Future<void> _loadInitial() async {
    try {
      final repo = context.read<LessonRepository>();
      // Fetch more items initially (30) to increase chances of finding matches
      // if the user applies a difficulty filter
      final freshLessons = await repo.fetchPagedGenreLessons(
        widget.languageCode,
        widget.genreKey,
        limit: 30, 
      );

      if (mounted) {
        setState(() {
          _allFetchedLessons = freshLessons;
          _isLoading = false;
          if (freshLessons.isEmpty) _hasReachedMax = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || _hasReachedMax || _allFetchedLessons.isEmpty) return;
    setState(() => _isLoadingMore = true);

    try {
      final repo = context.read<LessonRepository>();
      final lastLesson = _allFetchedLessons.last;

      final newLessons = await repo.fetchPagedGenreLessons(
        widget.languageCode,
        widget.genreKey,
        lastLesson: lastLesson,
        limit: 30,
      );

      if (mounted) {
        setState(() {
          if (newLessons.isEmpty) {
            _hasReachedMax = true;
          } else {
            final existingIds = _allFetchedLessons.map((l) => l.id).toSet();
            final uniqueNew = newLessons.where(
              (l) => !existingIds.contains(l.id),
            );
            _allFetchedLessons.addAll(uniqueNew);
          }
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final displayList = _displayedLessons; // Use the filtered getter

    if (displayList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.filter_list_off,
                size: 60, color: widget.isDark ? Colors.white24 : Colors.grey),
            const SizedBox(height: 16),
            Text(
              "No lessons match this difficulty.",
              style: TextStyle(
                color: widget.isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      );
    }

    if (widget.isDesktop) {
      return GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 400,
          mainAxisExtent: 280,
          crossAxisSpacing: 24,
          mainAxisSpacing: 24,
        ),
        itemCount: displayList.length + (_hasReachedMax ? 0 : 1),
        itemBuilder: (context, index) {
          if (index >= displayList.length) {
            return const Center(child: CircularProgressIndicator());
          }
          return _buildCard(displayList[index]);
        },
      );
    } else {
      return ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: displayList.length + (_hasReachedMax ? 0 : 1),
        separatorBuilder: (ctx, i) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          if (index >= displayList.length) {
            return const Center(child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ));
          }
          return _buildCard(displayList[index]);
        },
      );
    }
  }

  Widget _buildCard(LessonModel lesson) {
    if (lesson.type == 'text') {
      return TextLessonCard(
        lesson: lesson,
        vocabMap: widget.vocabMap,
        isDark: widget.isDark,
        onTap: () => _handleLessonTap(lesson),
        onOptionTap: () => showLessonOptions(context, lesson, widget.isDark),
      );
    } else {
      return VideoLessonCard(
        lesson: lesson,
        vocabMap: widget.vocabMap,
        isDark: widget.isDark,
        onTap: () => _handleLessonTap(lesson),
        onOptionTap: () => showLessonOptions(context, lesson, widget.isDark),
      );
    }
  }

  void _handleLessonTap(LessonModel lesson) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ReaderScreen(lesson: lesson)),
    );
  }
}