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
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // --- SHARED CONSTANTS ---
  final Map<String, String> _languageNames = {
    'es': 'Spanish',
    'fr': 'French',
    'de': 'German',
    'en': 'English',
    'it': 'Italian',
    'pt': 'Portuguese',
    'ja': 'Japanese',
  };

  // --- FILTERS ---
  String _selectedGlobalFilter = 'All';
  final List<String> _globalFilters = ['All', 'Videos', 'Audio', 'Text'];

  // --- GUIDED / IMPORTED TABS ---
  String _guidedTab = 'All';
  final List<String> _guidedTabsList = [
    'All',
    'Beginner',
    'Intermediate',
    'Advanced',
    'Imported',
  ];

  // --- NATIVE / IMMERSION TABS ---
  String _nativeDifficultyTab = 'All';
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
    context.read<VocabularyBloc>().add(VocabularyLoadRequested(user.id));
  }

  /// Calculates stats based on the lesson content vs the user's vocabulary map
  Map<String, int> _getLessonStats(
    LessonModel lesson,
    Map<String, VocabularyItem> vocabMap,
  ) {
    String fullText = lesson.content;
    if (lesson.transcript.isNotEmpty) {
      fullText = lesson.transcript.map((e) => e.text).join(" ");
    }

    final List<String> words = fullText.split(RegExp(r'(\s+)'));
    int newWords = 0;
    int knownWords = 0;
    final Set<String> uniqueWords = {};

    for (var word in words) {
      final cleanWord = word.toLowerCase().trim().replaceAll(
        RegExp(r'[^\w\s]'),
        '',
      );
      if (cleanWord.isEmpty) continue;
      if (uniqueWords.contains(cleanWord)) continue;

      uniqueWords.add(cleanWord);
      final vocabItem = vocabMap[cleanWord];

      if (vocabItem == null || vocabItem.status == 0) {
        newWords++;
      } else {
        knownWords++;
      }
    }
    return {'new': newWords, 'known': knownWords};
  }

  void _showStatsDialog(
    BuildContext context,
    int knownWords,
    String languageCode,
  ) {
    String currentLevel = "Beginner";
    String nextLevel = "A1";
    int nextGoal = 500;
    double progress = 0.0;

    if (knownWords < 500) {
      currentLevel = "Newcomer";
      nextLevel = "A1";
      nextGoal = 500;
      progress = knownWords / 500;
    } else if (knownWords < 1000) {
      currentLevel = "A1 (Beginner)";
      nextLevel = "A2";
      nextGoal = 1000;
      progress = (knownWords - 500) / 500;
    } else if (knownWords < 2000) {
      currentLevel = "A2 (Elementary)";
      nextLevel = "B1";
      nextGoal = 2000;
      progress = (knownWords - 1000) / 1000;
    } else if (knownWords < 4000) {
      currentLevel = "B1 (Intermediate)";
      nextLevel = "B2";
      nextGoal = 4000;
      progress = (knownWords - 2000) / 2000;
    } else if (knownWords < 8000) {
      currentLevel = "B2 (Upper Int.)";
      nextLevel = "C1";
      nextGoal = 8000;
      progress = (knownWords - 4000) / 4000;
    } else {
      currentLevel = "C1 (Advanced)";
      nextLevel = "C2";
      nextGoal = 16000;
      progress = (knownWords - 8000) / 8000;
    }

    final langName = _languageNames[languageCode] ?? 'Target Language';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          24 + MediaQuery.of(context).viewPadding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.auto_graph,
                    color: Colors.amber[800],
                    size: 28,
                  ),
                ),
                SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "$langName Progress",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    Text(
                      "You probably know more words.",
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
            Divider(height: 32),
            Center(
              child: Column(
                children: [
                  Text(
                    "Current Level",
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    currentLevel,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Next Goal: $nextLevel",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                Text(
                  "${nextGoal - knownWords} words to go",
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                valueColor: AlwaysStoppedAnimation(Colors.blue),
              ),
            ),
            Text(
              "$knownWords words known",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? Colors.white : Colors.black,
                  foregroundColor: isDark ? Colors.black : Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text("Keep Learning"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = (context.watch<AuthBloc>().state as AuthAuthenticated).user;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: bgColor,
        foregroundColor: textColor,
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.grey[50],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  width: 1,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: user.currentLanguage,
                  icon: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: Colors.grey,
                    ),
                  ),
                  isDense: true,
                  dropdownColor: isDark ? Color(0xFF2C2C2C) : Colors.white,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                    fontFamily: 'Roboto',
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
                    DropdownMenuItem(value: 'es', child: Text('🇪🇸 Spanish')),
                    DropdownMenuItem(value: 'fr', child: Text('🇫🇷 French')),
                    DropdownMenuItem(value: 'de', child: Text('🇩🇪 German')),
                    DropdownMenuItem(value: 'en', child: Text('🇬🇧 English')),
                    DropdownMenuItem(value: 'it', child: Text('🇮🇹 Italian')),
                    DropdownMenuItem(
                      value: 'pt',
                      child: Text('🇵🇹 Portuguese'),
                    ),
                    DropdownMenuItem(value: 'ja', child: Text('🇯🇵 Japanese')),
                  ],
                ),
              ),
            ),
            Spacer(),
            BlocBuilder<VocabularyBloc, VocabularyState>(
              builder: (context, vocabState) {
                int knownCount = 0;
                if (vocabState is VocabularyLoaded) {
                  knownCount = vocabState.items
                      .where(
                        (v) =>
                            v.status > 0 && v.language == user.currentLanguage,
                      )
                      .length;
                }
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => _showStatsDialog(
                      context,
                      knownCount,
                      user.currentLanguage,
                    ),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.amber.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.emoji_events_rounded,
                            size: 16,
                            color: Colors.amber[800],
                          ),
                          SizedBox(width: 6),
                          Text(
                            knownCount.toString(),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber[900],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      body: BlocBuilder<VocabularyBloc, VocabularyState>(
        builder: (context, vocabState) {
          Map<String, VocabularyItem> vocabMap = {};
          if (vocabState is VocabularyLoaded) {
            vocabMap = {
              for (var item in vocabState.items) item.word.toLowerCase(): item,
            };
          }

          return Column(
            children: [
              // 1. GLOBAL FILTERS
              _buildGlobalFilterChips(isDark),

              Expanded(
                child: BlocBuilder<LessonBloc, LessonState>(
                  builder: (context, lessonState) {
                    if (lessonState is LessonInitial) {
                      context.read<LessonBloc>().add(
                        LessonLoadRequested(user.id, user.currentLanguage),
                      );
                      return Center(child: CircularProgressIndicator());
                    }
                    if (lessonState is LessonLoading) {
                      return Center(child: CircularProgressIndicator());
                    }

                    if (lessonState is LessonLoaded) {
                      // Filter Lists
                      final nativeLessons = lessonState.lessons
                          .where((l) => l.type == 'video_native')
                          .toList();

                      final guidedLessons = lessonState.lessons
                          .where((l) => l.type == 'video')
                          .toList();

                      final importedLessons = lessonState.lessons
                          .where((l) => l.type == 'text')
                          .toList();

                      // VIEW LOGIC
                      if (_selectedGlobalFilter != 'All' &&
                          _selectedGlobalFilter != 'Videos') {
                        return _buildFilteredList(
                          lessonState.lessons,
                          vocabMap,
                          isDark,
                        );
                      }

                      // DEFAULT VIEW
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
                          padding: EdgeInsets.only(bottom: 80),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 2. GUIDED COURSES (Includes Imported Tab)
                              _buildGuidedSection(
                                guidedLessons,
                                importedLessons,
                                vocabMap,
                                isDark,
                                textColor,
                              ),

                              // 3. IMMERSION / TRENDING
                              _buildNativeSection(
                                nativeLessons,
                                vocabMap,
                                isDark,
                                textColor,
                              ),
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
      floatingActionButton: Material(
        color: Colors.transparent,
        elevation: 10,
        shadowColor: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(30),
        child: InkWell(
          onTap: () {
            _showCreateLessonDialog(
              context,
              user.id,
              user.currentLanguage,
              isFavoriteByDefault: false,
            );
          },
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E).withOpacity(0.90),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: Colors.white.withOpacity(0.15),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, color: Colors.white, size: 22),
                SizedBox(width: 8),
                Text(
                  'Import',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- WIDGETS & SECTIONS ---

  Widget _buildGlobalFilterChips(bool isDark) {
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
                color: isSelected
                    ? (isDark ? Colors.white : Colors.black)
                    : (isDark ? Colors.white10 : Colors.grey[100]),
                borderRadius: BorderRadius.circular(20),
                border: isSelected
                    ? null
                    : Border.all(
                        color: isDark
                            ? Colors.transparent
                            : Colors.grey.shade300,
                      ),
              ),
              alignment: Alignment.center,
              child: Text(
                category,
                style: TextStyle(
                  color: isSelected
                      ? (isDark ? Colors.black : Colors.white)
                      : (isDark ? Colors.white70 : Colors.black),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // --- GUIDED COURSES SECTION (with Imported Tab) ---
  Widget _buildGuidedSection(
    List<LessonModel> guidedLessons,
    List<LessonModel> importedLessons,
    Map<String, VocabularyItem> vocabMap,
    bool isDark,
    Color? textColor,
  ) {
    List<LessonModel> displayLessons = [];

    if (_guidedTab == 'Imported') {
      displayLessons = importedLessons;
    } else if (_guidedTab == 'All') {
      displayLessons = guidedLessons;
    } else {
      displayLessons = guidedLessons
          .where((l) => l.difficulty.toLowerCase() == _guidedTab.toLowerCase())
          .toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(
            "Guided Courses",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.black45,
            ),
          ),
        ),

        // Tabs
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: _guidedTabsList.map((tab) {
              final isSelected = _guidedTab == tab;
              return Padding(
                padding: const EdgeInsets.only(right: 24.0, bottom: 12),
                child: InkWell(
                  onTap: () => setState(() => _guidedTab = tab),
                  child: Column(
                    children: [
                      Text(
                        tab,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected
                              ? (isDark ? Colors.white : Colors.black)
                              : Colors.grey[500],
                        ),
                      ),
                      if (isSelected)
                        Container(
                          margin: EdgeInsets.only(top: 4),
                          height: 2,
                          width: 20,
                          color: Colors.blue,
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // Horizontal List
        if (displayLessons.isEmpty)
          Container(
            height: 260,
            alignment: Alignment.center,
            child: Text(
              _guidedTab == 'Imported'
                  ? "No imported lessons yet."
                  : "No guided courses found.",
              style: TextStyle(color: Colors.grey),
            ),
          )
        else
          SizedBox(
            height: 230, // Accommodate the Large Card size
            child: ListView.separated(
              padding: EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: displayLessons.length,
              separatorBuilder: (ctx, i) => SizedBox(width: 16),
              itemBuilder: (context, index) {
                return _buildVideoCardLarge(
                  context,
                  displayLessons[index],
                  vocabMap,
                  isDark,
                  textColor,
                );
              },
            ),
          ),
        // SizedBox(height: 16),
      ],
    );
  }

  // --- IMMERSION / TRENDING SECTION ---

  Widget _buildNativeSection(
    List<LessonModel> lessons,
    Map<String, VocabularyItem> vocabMap,
    bool isDark,
    Color? textColor,
  ) {
    final displayVideos = _nativeDifficultyTab == 'All'
        ? lessons
        : lessons
              .where(
                (l) =>
                    l.difficulty.toLowerCase() ==
                    _nativeDifficultyTab.toLowerCase(),
              )
              .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: Text(
            "Immersion",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.black45,
            ),
          ),
        ),

        // Tabs
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: _difficultyTabs.map((tab) {
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
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected
                              ? (isDark ? Colors.white : Colors.black)
                              : Colors.grey[500],
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

        // Horizontal List
        if (displayVideos.isEmpty)
          Container(
            height: 150,
            alignment: Alignment.center,
            child: Text(
              "No videos found",
              style: TextStyle(color: Colors.grey),
            ),
          )
        else
          SizedBox(
            height: 230, // Adjust this based on your card height
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16),
              physics: BouncingScrollPhysics(),
              itemCount: displayVideos.length,
              separatorBuilder: (ctx, i) => SizedBox(width: 16),
              itemBuilder: (context, index) {
                return _buildVideoCardLarge(
                  context,
                  displayVideos[index],
                  vocabMap,
                  isDark,
                  textColor,
                );
              },
            ),
          ),
      ],
    );
  }

  // --- CARD WIDGETS ---

  // Reused Large Card (Your specific layout)
  Widget _buildVideoCardLarge(
    BuildContext context,
    LessonModel lesson,
    Map<String, VocabularyItem> vocabMap,
    bool isDark,
    Color? textColor,
  ) {
    final stats = _getLessonStats(lesson, vocabMap);
    final int newCount = stats['new']!;
    final int knownCount = stats['known']!;

    double progress = lesson.progress > 0 ? lesson.progress / 100 : 0.0;
    if (progress == 0 && (knownCount + newCount) > 0) {
      progress = knownCount / (knownCount + newCount);
    }

    return Container(
      width: 280,
      margin: EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReaderScreen(lesson: lesson),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
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
                    color: isDark ? Colors.white10 : Colors.grey[200],
                    child: lesson.imageUrl != null
                        ? Image.network(lesson.imageUrl!, fit: BoxFit.cover)
                        : (lesson.type == 'text'
                              ? Center(
                                  child: Icon(
                                    Icons.article,
                                    size: 64,
                                    color: Colors.blue.withOpacity(0.5),
                                  ),
                                )
                              : Center(
                                  child: Icon(
                                    Icons.play_circle,
                                    size: 64,
                                    color: Colors.grey,
                                  ),
                                )),
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
                      value: progress,
                      minHeight: 4,
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                    ),
                  ),
                ),
              ],
            ),
            // SizedBox(height: 10),
            Text(
              lesson.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                height: 1.2,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            // Replaced with your exact sizing logic
            SizedBox(
              height: 20,
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.circle, size: 8, color: Colors.blue),
                        SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            "$newCount New",
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 12),
                        Icon(Icons.circle, size: 8, color: Colors.green),
                        SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            "$knownCount known",
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.more_vert, color: Colors.grey, size: 16),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: () =>
                        _showLessonOptions(context, lesson, isDark),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Backup text card (used for filtered views if user filters for Text specifically)
  Widget _buildTextLessonCard(
    BuildContext context,
    LessonModel lesson,
    Map<String, VocabularyItem> vocabMap,
    bool isDark,
  ) {
    final stats = _getLessonStats(lesson, vocabMap);
    final int newCount = stats['new']!;
    final int knownCount = stats['known']!;
    final double progress = (knownCount + newCount) == 0
        ? 0
        : knownCount / (knownCount + newCount);

    return Card(
      elevation: 0,
      color: isDark ? Colors.white10 : Colors.grey[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? Colors.transparent : Colors.grey.shade200,
        ),
      ),
      margin: EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReaderScreen(lesson: lesson),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.article, color: Colors.blue),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lesson.title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white70 : Colors.grey[800],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        Text(
                          lesson.content.replaceAll('\n', ' '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.more_vert, color: Colors.grey, size: 16),
                    constraints: BoxConstraints(),
                    padding: EdgeInsets.zero,
                    onPressed: () =>
                        _showLessonOptions(context, lesson, isDark),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: isDark
                            ? Colors.black26
                            : Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    "${(progress * 100).toInt()}%",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  SizedBox(width: 8),
                  Container(width: 1, height: 12, color: Colors.grey),
                  SizedBox(width: 8),
                  Text(
                    "$newCount New",
                    style: TextStyle(fontSize: 11, color: Colors.blue),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Updated to accept vocabMap
  Widget _buildFilteredList(
    List<LessonModel> lessons,
    Map<String, VocabularyItem> vocabMap,
    bool isDark,
  ) {
    final filtered = lessons.where((l) {
      if (_selectedGlobalFilter == 'Videos') {
        return l.type == 'video' || l.type == 'video_native';
      }
      if (_selectedGlobalFilter == 'Audio') return l.type == 'audio';
      if (_selectedGlobalFilter == 'Text') return l.type == 'text';
      return true;
    }).toList();

    return ListView.separated(
      padding: EdgeInsets.all(16),
      itemCount: filtered.length,
      separatorBuilder: (ctx, i) => SizedBox(height: 16),
      itemBuilder: (context, index) {
        return _buildTextLessonCard(context, filtered[index], vocabMap, isDark);
      },
    );
  }

  void _showLessonOptions(
    BuildContext context,
    LessonModel lesson,
    bool isDark,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (builderContext) => Container(
        decoration: BoxDecoration(
          color: isDark ? Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          top: 20,
          left: 0,
          right: 0,
          bottom: MediaQuery.of(builderContext).viewPadding.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: lesson.isFavorite
                      ? Colors.amber.withOpacity(0.1)
                      : (isDark ? Colors.white10 : Colors.grey[100]),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  lesson.isFavorite ? Icons.star : Icons.star_border,
                  color: lesson.isFavorite ? Colors.amber : Colors.grey,
                ),
              ),
              title: Text(
                lesson.isFavorite
                    ? 'Remove from Favorites'
                    : 'Add to Favorites',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              subtitle: Text(
                lesson.isFavorite
                    ? 'Removed from library.'
                    : 'Saved to library.',
                style: TextStyle(color: Colors.grey),
              ),
              onTap: () {
                final user =
                    (context.read<AuthBloc>().state as AuthAuthenticated).user;
                final updatedLesson = lesson.copyWith(
                  isFavorite: !lesson.isFavorite,
                  userId: user.id,
                );
                context.read<LessonBloc>().add(
                  LessonUpdateRequested(updatedLesson),
                );
                Navigator.pop(builderContext);
              },
            ),
            Divider(color: Colors.grey[800]),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.delete_outline, color: Colors.red),
              ),
              title: Text('Delete Lesson', style: TextStyle(color: Colors.red)),
              onTap: () {
                context.read<LessonBloc>().add(
                  LessonDeleteRequested(lesson.id),
                );
                Navigator.pop(builderContext);
              },
            ),
          ],
        ),
      ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final fullLangName =
        _languageNames[currentLanguage] ?? currentLanguage.toUpperCase();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? Color(0xFF1E1E1E) : Colors.white,
        title: Text(
          'Create New Lesson for $fullLangName',
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                  labelStyle: TextStyle(color: Colors.grey),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: contentController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  labelText: 'Content',
                  border: OutlineInputBorder(),
                  labelStyle: TextStyle(color: Colors.grey),
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
