import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_state.dart';
import 'package:linguaflow/constants/genre_constants.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/models/vocabulary_item.dart';
import 'package:linguaflow/services/repositories/lesson_repository.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/screens/home/widgets/lesson_cards.dart';
import 'package:linguaflow/screens/reader/reader_screen.dart';
import 'package:linguaflow/utils/utils.dart';

// Make sure GenreConstants is imported or defined. 
// (I have included it at the bottom of this file for reference)

class GenreFeedSection extends StatefulWidget {
  final String title;
  final String genreKey; // This might be "Books & Literature" (Bad for cache)
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
  State<GenreFeedSection> createState() => _GenreFeedSectionState();
}

class _GenreFeedSectionState extends State<GenreFeedSection>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  List<LessonModel> _lessons = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasReachedMax = false;

  @override
  bool get wantKeepAlive => true;

  // ---------------------------------------------------------------------------
  // FIX: Helper to get the Safe Internal Tag
  // ---------------------------------------------------------------------------
  /// If widget.genreKey is "Books & Literature", this returns "literature".
  /// If widget.genreKey is "Humor", this returns "comedy".
  /// If it's already "science", it returns "science".
  String get _internalGenreKey {
    // 1. Check if the key passed in is actually a Display Title
    if (GenreConstants.categoryMap.containsKey(widget.genreKey)) {
      return GenreConstants.categoryMap[widget.genreKey]!;
    }
    // 2. Otherwise, assume it's already the internal ID
    return widget.genreKey;
  }

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
    final repo = context.read<LessonRepository>();
    final authState = context.read<AuthBloc>().state;
    String userId = '';
    
    if (authState is AuthAuthenticated) {
      userId = authState.user.id;
    }

    // Use the safe key for all operations
    final safeKey = _internalGenreKey;

    // ------------------------------------------------------------
    // 1. CACHE FIRST: Use safeKey (e.g. 'literature')
    // ------------------------------------------------------------
    if (userId.isNotEmpty) {
      final cached = await repo.getCachedGenreLessons(
        userId, 
        widget.languageCode, 
        safeKey // <--- FIX
      );
      
      if (mounted && cached.isNotEmpty) {
        setState(() {
          _lessons = cached;
          _isLoading = false; 
        });
      }
    }

    // ------------------------------------------------------------
    // 2. NETWORK UPDATE: Use safeKey
    // ------------------------------------------------------------
    try {
      final freshLessons = await repo.fetchPagedGenreLessons(
        widget.languageCode,
        safeKey, // <--- FIX
        limit: 10,
      );

      if (mounted) {
        setState(() {
          _lessons = freshLessons;
          _isLoading = false;
        });
      }

      // ------------------------------------------------------------
      // 3. SAVE TO CACHE: Use safeKey
      // ------------------------------------------------------------
      if (userId.isNotEmpty && freshLessons.isNotEmpty) {
        // This will now save to 'genre_literature_cache.json'
        // instead of 'genre_Books & Literature_cache.json'
        repo.cacheGenreLessons(userId, widget.languageCode, safeKey, freshLessons);
      }

    } catch (e) {
      if (mounted && _lessons.isEmpty) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || _hasReachedMax || _lessons.isEmpty) return;
    setState(() => _isLoadingMore = true);

    try {
      final repo = context.read<LessonRepository>();
      final lastLesson = _lessons.last;
      
      // Use the safe key
      final safeKey = _internalGenreKey; 

      final newLessons = await repo.fetchPagedGenreLessons(
        widget.languageCode,
        safeKey, // <--- FIX
        lastLesson: lastLesson,
        limit: 10,
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
    super.build(context);

    if (!_isLoading && _lessons.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Text(
            widget.title, // Keep showing the nice title ("Books & Literature") to the user
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
                        showLessonOptions(context, lesson, widget.isDark);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}
