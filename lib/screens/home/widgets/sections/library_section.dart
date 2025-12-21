import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/models/vocabulary_item.dart';
import 'package:linguaflow/screens/home/widgets/lesson_cards.dart';
import 'package:linguaflow/screens/reader/reader_screen.dart';
import 'package:linguaflow/services/repositories/lesson_repository.dart';
import 'package:linguaflow/utils/utils.dart';


// ==============================================================================
// 3. LIBRARY SECTION
// ==============================================================================
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

  @override
  void didUpdateWidget(LibrarySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.lessons.length != oldWidget.lessons.length) {
      setState(() {
        _lessons = List.from(widget.lessons);
        _hasReachedMax = false;
      });
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loading = true);
    try {
      final repo = context.read<LessonRepository>();
      // Library also contains text books, so we look for yt_ OR standard IDs
      final cloudLessons = _lessons
          .where((l) => l.id.startsWith('yt_') || l.id.contains('_'))
          .toList();
      final lastLesson = cloudLessons.isNotEmpty ? cloudLessons.last : null;

      final newItems = await repo.fetchPagedCategory(
        widget.languageCode,
        'book',
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
    var sorted = List<LessonModel>.from(_lessons)
      ..sort((a, b) {
        if (a.difficulty == 'beginner' && b.difficulty != 'beginner') return -1;
        if (a.difficulty != 'beginner' && b.difficulty == 'beginner') return 1;
        return 0;
      });

    final raw = _tab == 'All'
        ? sorted
        : sorted
              .where((l) => l.difficulty.toLowerCase() == _tab.toLowerCase())
              .toList();
    final display = deduplicateSeries(raw);

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
              return l.type == 'text'
                  ? TextLessonCard(
                      lesson: l,
                      vocabMap: widget.vocabMap,
                      isDark: widget.isDark,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (c) => ReaderScreen(lesson: l),
                        ),
                      ),
                      onOptionTap: () =>
                          showLessonOptions(context, l, widget.isDark),
                    )
                  : VideoLessonCard(
                      lesson: l,
                      vocabMap: widget.vocabMap,
                      isDark: widget.isDark,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (c) => ReaderScreen(lesson: l),
                        ),
                      ),
                      onOptionTap: () =>
                          showLessonOptions(context, l, widget.isDark),
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
                color: Colors.green,
              ),
          ],
        ),
      ),
    );
  }
}
