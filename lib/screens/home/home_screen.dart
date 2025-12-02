import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/lesson/lesson_bloc.dart';
import 'package:linguaflow/blocs/vocabulary/vocabulary_bloc.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/models/vocabulary_item.dart';
import 'package:linguaflow/screens/reader/reader_screen.dart';
import 'package:linguaflow/services/lesson_service.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Global Filter (Top of screen)
  String _selectedGlobalFilter = 'All';
  final List<String> _globalFilters = ['All', 'Videos', 'Audio', 'Text'];

  // Video Section Specific Filter
  String _videoDifficultyTab = 'All';
  final List<String> _difficultyTabs = [
    'All',
    'Beginner',
    'Intermediate',
    'Advanced',
  ];

  @override
  void initState() {
    super.initState();
    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
    // Load Vocabulary when Home Screen inits so we have the data for calculations
    context.read<VocabularyBloc>().add(VocabularyLoadRequested(user.id));
  }

  // --- HELPER: Calculate Stats for a Lesson ---
  Map<String, int> _getLessonStats(
    LessonModel lesson,
    Map<String, VocabularyItem> vocabMap,
  ) {
    // 1. Get all text
    String fullText = lesson.content;
    if (lesson.transcript.isNotEmpty) {
      fullText = lesson.transcript.map((e) => e.text).join(" ");
    }

    // 2. Split into words (Regex matches whitespace)
    final List<String> words = fullText.split(RegExp(r'(\s+)'));

    int newWords = 0;
    int knownWords = 0;
    // Use a Set to avoid counting the same word twice in one lesson (Unique word count)
    final Set<String> uniqueWords = {};

    for (var word in words) {
      final cleanWord = word.toLowerCase().trim().replaceAll(
        RegExp(r'[^\w\s]'),
        '',
      );
      if (cleanWord.isEmpty) continue;
      if (uniqueWords.contains(cleanWord)) continue; // Skip duplicates

      uniqueWords.add(cleanWord);

      final vocabItem = vocabMap[cleanWord];

      // Logic:
      // If item is null or status is 0 -> New
      // If status > 0 (1,2,3,4,5) -> Known (or learning)
      if (vocabItem == null || vocabItem.status == 0) {
        newWords++;
      } else {
        knownWords++;
      }
    }

    return {'new': newWords, 'known': knownWords};
  }

  @override
  Widget build(BuildContext context) {
    final user = (context.watch<AuthBloc>().state as AuthAuthenticated).user;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: Row(
          children: [
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: user.currentLanguage,
                icon: Icon(Icons.keyboard_arrow_down, color: Colors.blue),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    context.read<AuthBloc>().add(
                      AuthTargetLanguageChanged(newValue),
                    );
                    context.read<LessonBloc>().add(
                      LessonLoadRequested(user.id, newValue),
                    );
                    context.read<VocabularyBloc>().add(
                      VocabularyLoadRequested(user.id),
                    );
                  }
                },
                items: [
                  DropdownMenuItem(value: 'es', child: Text('Spanish')),
                  DropdownMenuItem(value: 'fr', child: Text('French')),
                  DropdownMenuItem(value: 'de', child: Text('German')),
                  DropdownMenuItem(value: 'en', child: Text('English')),
                  DropdownMenuItem(value: 'it', child: Text('Italian')),
                  DropdownMenuItem(value: 'pt', child: Text('Portuguese')),
                  DropdownMenuItem(value: 'ja', child: Text('Japanese')),
                ],
              ),
            ),
            Spacer(),
            // REAL TOTAL KNOWN WORDS COUNT
            BlocBuilder<VocabularyBloc, VocabularyState>(
              builder: (context, vocabState) {
                int totalKnown = 0;
                if (vocabState is VocabularyLoaded) {
                  // FIXED: used vocabState.items instead of vocabulary
                  totalKnown = vocabState.items
                      .where((v) => v.status > 0)
                      .length;
                }

                return Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.emoji_events,
                        size: 16,
                        color: Colors.amber[800],
                      ),
                      SizedBox(width: 4),
                      Text(
                        totalKnown.toString(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber[900],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
      // Wrap Body with Vocabulary Builder to pass data down
      body: BlocBuilder<VocabularyBloc, VocabularyState>(
        builder: (context, vocabState) {
          // Prepare a fast lookup map for calculations
          Map<String, VocabularyItem> vocabMap = {};
          if (vocabState is VocabularyLoaded) {
            // FIXED: used vocabState.items instead of vocabulary
            vocabMap = {
              for (var item in vocabState.items) item.word.toLowerCase(): item,
            };
          }

          return Column(
            children: [
              _buildGlobalFilterChips(),
              Expanded(
                child: BlocBuilder<LessonBloc, LessonState>(
                  builder: (context, lessonState) {
                    if (lessonState is LessonInitial) {
                      context.read<LessonBloc>().add(
                        LessonLoadRequested(user.id, user.currentLanguage),
                      );
                      return Center(child: CircularProgressIndicator());
                    }
                    if (lessonState is LessonLoading)
                      return Center(child: CircularProgressIndicator());

                    if (lessonState is LessonLoaded) {
                      if (_selectedGlobalFilter != 'All' &&
                          _selectedGlobalFilter != 'Videos') {
                        return _buildFilteredList(lessonState.lessons);
                      }

                      return RefreshIndicator(
                        onRefresh: () async {
                          context.read<LessonBloc>().add(
                            LessonLoadRequested(user.id, user.currentLanguage),
                          );
                          context.read<VocabularyBloc>().add(
                            VocabularyLoadRequested(user.id),
                          );
                        },
                        child: SingleChildScrollView(
                          padding: EdgeInsets.only(bottom: 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // PASS VOCAB MAP TO SECTIONS
                              _buildVideoSection(lessonState.lessons, vocabMap),
                              _buildPopularTextSection(lessonState.lessons),
                            ],
                          ),
                        ),
                      );
                    }
                    return Center(child: Text('Something went wrong'));
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showCreateLessonDialog(
            context,
            user.id,
            user.currentLanguage,
            isFavoriteByDefault: false,
          );
        },
        backgroundColor: Colors.blue,
        icon: Icon(Icons.add),
        label: Text('New Lesson'),
      ),
    );
  }

  // --- SECTION 1: VIDEO LESSONS ---
  Widget _buildVideoSection(
    List<LessonModel> allLessons,
    Map<String, VocabularyItem> vocabMap,
  ) {
    final allVideos = allLessons.where((l) => l.type == 'video').toList();

    final displayVideos = _videoDifficultyTab == 'All'
        ? allVideos
        : allVideos
              .where(
                (l) =>
                    l.difficulty.toLowerCase() ==
                    _videoDifficultyTab.toLowerCase(),
              )
              .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Text(
                "Guided Courses",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black45,
                ),
              ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: _difficultyTabs.map((tab) {
              final isSelected = _videoDifficultyTab == tab;
              return Padding(
                padding: const EdgeInsets.only(right: 24.0, bottom: 12),
                child: InkWell(
                  onTap: () => setState(() => _videoDifficultyTab = tab),
                  child: Column(
                    children: [
                      Text(
                        tab,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected ? Colors.black : Colors.grey[500],
                        ),
                      ),
                      if (isSelected)
                        Container(
                          margin: EdgeInsets.only(top: 4),
                          height: 2,
                          width: 20,
                          color: Colors.red,
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        if (displayVideos.isEmpty)
          Container(
            height: 200,
            alignment: Alignment.center,
            child: Text(
              "No videos found",
              style: TextStyle(color: Colors.grey),
            ),
          )
        else
          SizedBox(
            height: 250,
            child: ListView.separated(
              padding: EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: displayVideos.length,
              separatorBuilder: (ctx, i) => SizedBox(width: 16),
              itemBuilder: (context, index) {
                return _buildVideoCardLarge(
                  context,
                  displayVideos[index],
                  vocabMap,
                );
              },
            ),
          ),
      ],
    );
  }

  // --- SECTION 2: TEXT LESSONS ---
  Widget _buildPopularTextSection(List<LessonModel> allLessons) {
    final textLessons = allLessons.where((l) => l.type == 'text').toList();
    if (textLessons.isEmpty) return SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            children: [
              Text(
                "Your Imported Lessons",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black45,
                ),
              ),
              Spacer(),
            ],
          ),
        ),
        ListView.builder(
          padding: EdgeInsets.symmetric(horizontal: 16),
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: textLessons.length,
          itemBuilder: (context, index) {
            return _buildTextLessonCard(context, textLessons[index]);
          },
        ),
      ],
    );
  }

  // --- WIDGETS ---

  Widget _buildVideoCardLarge(
    BuildContext context,
    LessonModel lesson,
    Map<String, VocabularyItem> vocabMap,
  ) {
    // CALCULATE STATS HERE
    final stats = _getLessonStats(lesson, vocabMap);
    final int newCount = stats['new']!;
    final int knownCount = stats['known']!;

    return Container(
      width: 280,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReaderScreen(lesson: lesson),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 160,
                    width: 280,
                    color: Colors.grey[200],
                    child: lesson.imageUrl != null
                        ? Image.network(lesson.imageUrl!, fit: BoxFit.cover)
                        : null,
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      lesson.difficulty.toUpperCase(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: ClipRRect(
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(12),
                    ),
                    child: LinearProgressIndicator(
                      value: (knownCount + newCount) == 0
                          ? 0
                          : knownCount / (knownCount + newCount),
                      minHeight: 4,
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            Text(
              lesson.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                height: 1.2,
              ),
            ),
            SizedBox(height: 6),
            // REAL STATS DISPLAY
            Row(
              children: [
                Icon(Icons.circle, size: 8, color: Colors.blue),
                SizedBox(width: 4),
                Text(
                  "$newCount New",
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                SizedBox(width: 12),
                Icon(Icons.circle, size: 8, color: Colors.amber),
                SizedBox(width: 4),
                Text(
                  "$knownCount known",
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextLessonCard(BuildContext context, LessonModel lesson) {
    return Card(
      elevation: 0,
      color: Colors.grey[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      margin: EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReaderScreen(lesson: lesson),
            ),
          );
        },
        contentPadding: EdgeInsets.all(12),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.article, color: Colors.blue),
        ),
        title: Text(
          lesson.title,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          lesson.content.replaceAll('\n', ' '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      ),
    );
  }

  Widget _buildGlobalFilterChips() {
    return Container(
      height: 60,
      padding: EdgeInsets.symmetric(vertical: 10),
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _globalFilters.length,
        separatorBuilder: (ctx, i) => SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = _globalFilters[index];
          final isSelected = _selectedGlobalFilter == category;
          return GestureDetector(
            onTap: () => setState(() => _selectedGlobalFilter = category),
            child: AnimatedContainer(
              duration: Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? Colors.black : Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
                border: isSelected
                    ? null
                    : Border.all(color: Colors.grey.shade300),
              ),
              alignment: Alignment.center,
              child: Text(
                category,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilteredList(List<LessonModel> lessons) {
    final filtered = lessons.where((l) {
      if (_selectedGlobalFilter == 'Videos') return l.type == 'video';
      if (_selectedGlobalFilter == 'Audio') return l.type == 'audio';
      if (_selectedGlobalFilter == 'Text') return l.type == 'text';
      return true;
    }).toList();

    return ListView.separated(
      padding: EdgeInsets.all(16),
      itemCount: filtered.length,
      separatorBuilder: (ctx, i) => SizedBox(height: 16),
      itemBuilder: (context, index) {
        return _buildTextLessonCard(context, filtered[index]);
      },
    );
  }

  void _showCreateLessonDialog(
    BuildContext context,
    String userId,
    String currentLanguage, {
    required bool isFavoriteByDefault,
  }) {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    final lessonBloc = context.read<LessonBloc>();
    final lessonService = context.read<LessonService>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Create New Lesson'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: contentController,
                decoration: InputDecoration(
                  labelText: 'Content',
                  border: OutlineInputBorder(),
                ),
                maxLines: 6,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.isNotEmpty &&
                  contentController.text.isNotEmpty) {
                final sentences = lessonService.splitIntoSentences(
                  contentController.text,
                );
                final lesson = LessonModel(
                  id: '',
                  userId: userId,
                  title: titleController.text,
                  language: currentLanguage,
                  content: contentController.text,
                  sentences: sentences,
                  createdAt: DateTime.now(),
                  progress: 0,
                  isFavorite: isFavoriteByDefault,
                  type: 'text',
                );
                lessonBloc.add(LessonCreateRequested(lesson));
                Navigator.pop(dialogContext);
              }
            },
            child: Text('Create'),
          ),
        ],
      ),
    );
  }
}
