import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/models/vocabulary_item.dart';
import 'package:linguaflow/screens/home/widgets/lesson_cards.dart';
import 'package:linguaflow/screens/reader/reader_screen.dart';
import 'package:linguaflow/services/repositories/lesson_repository.dart';
import 'package:linguaflow/utils/utils.dart'; // for showLessonOptions

class FilteredGenreList extends StatefulWidget {
  final String genreKey;
  final String languageCode;
  final Map<String, VocabularyItem> vocabMap;
  final bool isDark;
  final bool isDesktop;

  const FilteredGenreList({
    super.key,
    required this.genreKey,
    required this.languageCode,
    required this.vocabMap,
    required this.isDark,
    required this.isDesktop,
  });

  @override
  State<FilteredGenreList> createState() => _FilteredGenreListState();
}

class _FilteredGenreListState extends State<FilteredGenreList> {
  final ScrollController _scrollController = ScrollController();
  List<LessonModel> _lessons = [];
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
    if (oldWidget.genreKey != widget.genreKey) {
      // Reload if genre changes
      _lessons.clear();
      _hasReachedMax = false;
      _isLoading = true;
      setState(() {});
      _loadInitial();
    }
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

  Future<void> _loadInitial() async {
    try {
      final repo = context.read<LessonRepository>();
      
      // Use the method you already use in GenreFeedSection
      final freshLessons = await repo.fetchPagedGenreLessons(
        widget.languageCode,
        widget.genreKey,
        limit: 20, // Load more for vertical list
      );

      if (mounted) {
        setState(() {
          _lessons = freshLessons;
          _isLoading = false;
          if (freshLessons.isEmpty) _hasReachedMax = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || _hasReachedMax || _lessons.isEmpty) return;
    setState(() => _isLoadingMore = true);

    try {
      final repo = context.read<LessonRepository>();
      final lastLesson = _lessons.last;

      final newLessons = await repo.fetchPagedGenreLessons(
        widget.languageCode,
        widget.genreKey,
        lastLesson: lastLesson,
        limit: 20,
      );

      if (mounted) {
        setState(() {
          if (newLessons.isEmpty) {
            _hasReachedMax = true;
          } else {
            final existingIds = _lessons.map((l) => l.id).toSet();
            final uniqueNew = newLessons.where(
              (l) => !existingIds.contains(l.id),
            );
            _lessons.addAll(uniqueNew);
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

    if (_lessons.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off,
                size: 60, color: widget.isDark ? Colors.white24 : Colors.grey),
            const SizedBox(height: 16),
            Text(
              "No lessons found for this genre.",
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
        itemCount: _lessons.length + (_hasReachedMax ? 0 : 1),
        itemBuilder: (context, index) {
          if (index >= _lessons.length) {
            return const Center(child: CircularProgressIndicator());
          }
          return _buildCard(_lessons[index]);
        },
      );
    } else {
      return ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: _lessons.length + (_hasReachedMax ? 0 : 1),
        separatorBuilder: (ctx, i) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          if (index >= _lessons.length) {
            return const Center(child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ));
          }
          return _buildCard(_lessons[index]);
        },
      );
    }
  }

  Widget _buildCard(LessonModel lesson) {
    // Reusing your logic for card selection
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