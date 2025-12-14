import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/models/vocabulary_item.dart';
import 'package:linguaflow/services/repositories/lesson_repository.dart';
import 'package:linguaflow/screens/home/widgets/lesson_cards.dart'; // Ensure correct import for VideoLessonCard
import 'package:linguaflow/screens/reader/reader_screen.dart';
import 'package:linguaflow/screens/home/widgets/home_dialogs.dart'; // For options

class GenreFeedSection extends StatefulWidget {
  final String title;
  final String genreKey;
  final String languageCode;
  final Map<String, VocabularyItem> vocabMap;
  final bool isDark;

  const GenreFeedSection({
    super.key,
    required this.title,
    required this.genreKey,
    required this.languageCode,
    required this.vocabMap,
    required this.isDark,
  });

  @override
  _GenreFeedSectionState createState() => _GenreFeedSectionState();
}

class _GenreFeedSectionState extends State<GenreFeedSection>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  List<LessonModel> _lessons = [];
  bool _isLoading = true; // Initial load
  bool _isLoadingMore = false;
  bool _hasReachedMax = false;

  @override
  bool get wantKeepAlive => true; // Keeps the list alive when scrolling vertical

  @override
  void initState() {
    super.initState();
    _loadInitial();
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

  Future<void> _loadInitial() async {
    try {
      final repo = context.read<LessonRepository>();
      final results = await repo.fetchPagedGenreLessons(
        widget.languageCode,
        widget.genreKey,
        limit: 10,
      );

      if (mounted) {
        setState(() {
          _lessons = results;
          _isLoading = false;
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
        limit: 10,
      );

      if (mounted) {
        setState(() {
          if (newLessons.isEmpty) {
            _hasReachedMax = true;
          } else {
            // Deduplicate just in case
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
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    // If loaded and empty, hide the section entirely
    if (!_isLoading && _lessons.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Text(
            widget.title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: widget.isDark ? Colors.white70 : Colors.black45,
            ),
          ),
        ),
        SizedBox(
          height: 240,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: _lessons.length + 1,
                  separatorBuilder: (ctx, i) => const SizedBox(width: 16),
                  itemBuilder: (context, index) {
                    if (index >= _lessons.length) {
                      if (_hasReachedMax) return const SizedBox(width: 20);
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    }

                    final lesson = _lessons[index];
                    return VideoLessonCard(
                      lesson: lesson,
                      vocabMap: widget.vocabMap,
                      isDark: widget.isDark,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ReaderScreen(lesson: lesson),
                          ),
                        );
                      },
                      onOptionTap: () {
                        // Ensure showLessonOptions is available/imported
                        // showLessonOptions(context, lesson, widget.isDark);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}
