import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:linguaflow/constants/genre_constants.dart';
import 'package:linguaflow/screens/home/widgets/sections/genre_feed_section.dart';
import 'package:linguaflow/utils/utils.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

// BLOCS
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/lesson/lesson_bloc.dart';
import 'package:linguaflow/blocs/vocabulary/vocabulary_bloc.dart';

// MODELS
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/models/vocabulary_item.dart';

// WIDGETS & SECTIONS
import 'package:linguaflow/screens/home/widgets/sections/home_sections.dart';
// ^^^ Ensure this file contains the Guided/Immersion/Library sections we just fixed
import 'package:linguaflow/screens/home/widgets/audio_section.dart';
import 'package:linguaflow/screens/home/widgets/lesson_cards.dart';
import 'package:linguaflow/screens/home/widgets/audio_player_overlay.dart';
import 'package:linguaflow/screens/home/widgets/home_dialogs.dart';
import 'package:linguaflow/screens/home/widgets/home_language_dialogs.dart';
import 'package:linguaflow/widgets/lesson_import_dialog.dart';
import 'package:linguaflow/widgets/premium_lock_dialog.dart';

// SCREENS
import 'package:linguaflow/screens/reader/reader_screen.dart';
import 'package:linguaflow/screens/search/library_search_delegate.dart';

// UTILS
import 'package:linguaflow/screens/home/utils/home_utils.dart';
import 'package:linguaflow/utils/language_helper.dart';
import 'package:linguaflow/services/web_scraper_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // --- FILTERS ---
  String _selectedGlobalFilter = 'All';
  final List<String> _globalFilters = ['All', 'Videos', 'Audio', 'Text'];

  // --- SHARE LISTENER SUBSCRIPTION ---
  late StreamSubscription _intentDataStreamSubscription;
  bool _initialIntentHandled = false;

  @override
  void initState() {
    super.initState();
    _initShareListener();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated) {
        final user = authState.user;

        if (user.currentLanguage.isEmpty) {
          HomeLanguageDialogs.showNativeLanguageSelector(
            context,
            isFirstSetup: true,
          );
        } else if (user.nativeLanguage.isEmpty) {
          HomeLanguageDialogs.showNativeLanguageSelector(
            context,
            isFirstSetup: false,
          );
        } else {
          context.read<VocabularyBloc>().add(VocabularyLoadRequested(user.id));
        }
      }
    });
  }

  @override
  void dispose() {
    _intentDataStreamSubscription.cancel();
    super.dispose();
  }

  // --- SHARE LISTENER LOGIC ---
  void _initShareListener() {
    _intentDataStreamSubscription = ReceiveSharingIntent.instance
        .getMediaStream()
        .listen((List<SharedMediaFile> value) {
          if (value.isNotEmpty && value.first.path.isNotEmpty) {
            _handleSharedContent(value.first.path);
          }
        }, onError: (err) => debugPrint("getMediaStream error: $err"));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_initialIntentHandled) return;
      ReceiveSharingIntent.instance.getInitialMedia().then((
        List<SharedMediaFile> value,
      ) {
        if (value.isNotEmpty && value.first.path.isNotEmpty) {
          _initialIntentHandled = true;
          _handleSharedContent(value.first.path);
          ReceiveSharingIntent.instance.reset();
        }
      });
    });
  }

  Future<void> _handleSharedContent(String sharedText) async {
    if (!mounted) return;
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;
    final user = authState.user;

    final uri = Uri.tryParse(sharedText);
    bool isUrl = uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
    bool isYoutube = false;

    if (isUrl) {
      final host = uri.host.toLowerCase();
      if (host.contains('youtube.com') || host.contains('youtu.be'))
        isYoutube = true;
    }

    String initialTitle = "";
    String initialContent = "";
    String? initialMediaUrl;
    int targetTab = 0;

    if (isYoutube) {
      targetTab = 1;
      initialMediaUrl = sharedText;
    } else if (isUrl) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => const Center(child: CircularProgressIndicator()),
      );
      final data = await WebScraperService.scrapeUrl(sharedText);
      if (!mounted) return;
      Navigator.pop(context);

      if (data != null) {
        initialTitle = data['title']!;
        initialContent = data['content']!;
      } else {
        initialContent = sharedText;
      }
    } else {
      initialContent = sharedText;
    }

    if (!mounted) return;

    LessonImportDialog.show(
      context,
      user.id,
      user.currentLanguage,
      LanguageHelper.availableLanguages,
      isFavoriteByDefault: false,
      initialTitle: initialTitle,
      initialContent: initialContent,
      initialMediaUrl: initialMediaUrl,
      initialTabIndex: targetTab,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;

    if (authState is! AuthAuthenticated) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final user = authState.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    // Helper to get 'es', 'fr', etc. for API calls
    final String currentLangCode = LanguageHelper.getLangCode(
      user.currentLanguage,
    );

    if (user.currentLanguage.isEmpty) {
      return Scaffold(
        backgroundColor: bgColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.translate,
                size: 64,
                color: Colors.grey.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              const Text(
                "Welcome! Setting up...",
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: _buildAppBar(context, user, isDark, textColor),
      body: Stack(
        children: [
          BlocBuilder<VocabularyBloc, VocabularyState>(
            builder: (context, vocabState) {
              Map<String, VocabularyItem> vocabMap = {};
              if (vocabState is VocabularyLoaded) {
                vocabMap = {
                  for (var item in vocabState.items)
                    item.word.toLowerCase(): item,
                };
              }

              return Column(
                children: [
                  _buildGlobalFilterChips(isDark),
                  Expanded(
                    child: BlocBuilder<LessonBloc, LessonState>(
                      builder: (context, lessonState) {
                        if (lessonState is LessonInitial) {
                          if (user.currentLanguage.isNotEmpty) {
                            context.read<LessonBloc>().add(
                              LessonLoadRequested(
                                user.id,
                                user.currentLanguage,
                              ),
                            );
                          }
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (lessonState is LessonLoading) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (lessonState is LessonLoaded) {
                          var processedLessons = lessonState.lessons;

                          // --- VERTICAL LIST MODE (Global Filters) ---
                          if (_selectedGlobalFilter != 'All') {
                            return _buildFilteredList(
                              processedLessons,
                              vocabMap,
                              isDark,
                            );
                          }

                          // --- DASHBOARD MODE (Horizontal Sections) ---
                          final nativeLessons = processedLessons
                              .where((l) => l.type == 'video_native')
                              .toList();
                          final guidedLessons = processedLessons
                              .where((l) => l.type == 'video')
                              .toList();
                          final audioLessons = processedLessons
                              .where((l) => l.type == 'audio')
                              .toList();
                          final libraryLessons = processedLessons
                              .where(
                                (l) =>
                                    l.type == 'text' &&
                                    l.userId.startsWith('system'),
                              )
                              .toList();
                          final importedLessons = processedLessons
                              .where(
                                (l) =>
                                    (l.type == 'text' ||
                                        l.type == 'video' ||
                                        (l.type == 'audio' && l.isLocal)) &&
                                    !l.userId.startsWith('system'),
                              )
                              .toList();

                          return RefreshIndicator(
                            onRefresh: () async {
                              context.read<LessonBloc>().add(
                                LessonLoadRequested(
                                  user.id,
                                  user.currentLanguage,
                                ),
                              );
                              context.read<VocabularyBloc>().add(
                                VocabularyLoadRequested(user.id),
                              );
                            },
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.only(bottom: 120),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 1. GUIDED COURSES (Horizontal Infinite)
                                  GuidedCoursesSection(
                                    languageCode:
                                        currentLangCode, // PASSED for pagination
                                    guidedLessons: guidedLessons,
                                    importedLessons: importedLessons,
                                    vocabMap: vocabMap,
                                    isDark: isDark,
                                  ),

                                  _buildAIStoryButton(context, isDark),

                                  // 2. IMMERSION / VIDEOS (Horizontal Infinite)
                                  ImmersionSection(
                                    languageCode:
                                        currentLangCode, // PASSED for pagination
                                    lessons: nativeLessons,
                                    vocabMap: vocabMap,
                                    isDark: isDark,
                                  ),

                                  // 3. AUDIO (Standard - Audio logic is unique)
                                  if (audioLessons.isNotEmpty)
                                    AudioLibrarySection(
                                      lessons: audioLessons,
                                      isDark: isDark,
                                    ),

                                  // 4. LIBRARY / BOOKS (Horizontal Infinite)
                                  LibrarySection(
                                    languageCode:
                                        currentLangCode, // PASSED for pagination
                                    lessons: libraryLessons,
                                    vocabMap: vocabMap,
                                    isDark: isDark,
                                  ),
                                  ...GenreConstants.categoryMap.entries.map((entry) {
  return GenreFeedSection(
    title: entry.key,      // e.g., "Science & Tech"
    genreKey: entry.value, // e.g., "science"
    languageCode: currentLangCode,
    vocabMap: vocabMap,
    isDark: isDark,
  );
}).toList(),
                                  // Removed HomeVideoFeeds() as requested
                                  const SizedBox(height: 40),
                                ],
                              ),
                            ),
                          );
                        }
                        return const Center(
                          child: Text('Something went wrong'),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
          const AudioPlayerOverlay(),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            HomeUtils.buildFloatingButton(
              label: "Learn",
              icon: Icons.school_rounded,
              onTap: () => HomeUtils.navigateToLearnScreen(context),
            ),
            HomeUtils.buildFloatingButton(
              label: "Import",
              icon: Icons.add_rounded,
              onTap: () => LessonImportDialog.show(
                context,
                user.id,
                user.currentLanguage,
                LanguageHelper.availableLanguages,
                isFavoriteByDefault: false,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- APP BAR ---
  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    dynamic user,
    bool isDark,
    Color? textColor,
  ) {
    final bool isPremium = user.isPremium;

    return AppBar(
      elevation: 0,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      foregroundColor: textColor,
      toolbarHeight: 70,
      title: BlocBuilder<VocabularyBloc, VocabularyState>(
        builder: (context, vocabState) {
          int knownCount = 0;
          if (vocabState is VocabularyLoaded) {
            knownCount = vocabState.items
                .where(
                  (v) => v.status > 0 && v.language == user.currentLanguage,
                )
                .length;
          }
          final levelStats = HomeDialogs.getLevelDetails(knownCount);
          final String displayLevel = knownCount > 0
              ? levelStats['fullLabel']
              : user.currentLevel;
          final int nextGoal = levelStats['nextGoal'];

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () =>
                    HomeLanguageDialogs.showTargetLanguageSelector(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? Colors.white12 : Colors.grey.shade300,
                      width: 2,
                    ),
                    color: isDark ? Colors.black26 : Colors.white,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    LanguageHelper.getFlagEmoji(user.currentLanguage),
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () => HomeLanguageDialogs.showLevelSelector(
                    context,
                    displayLevel,
                    user.currentLanguage,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              displayLevel,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 20,
                            color: isDark
                                ? Colors.white54
                                : Colors.grey.shade600,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            "$knownCount / $nextGoal words",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
      actions: [
        BlocBuilder<LessonBloc, LessonState>(
          builder: (context, state) {
            final isLoaded = state is LessonLoaded;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: InkWell(
                onTap: isLoaded
                    ? () {
                        showSearch(
                          context: context,
                          delegate: LibrarySearchDelegate(
                            lessons: state.lessons,
                            isDark: isDark,
                          ),
                        );
                      }
                    : null,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 35,
                  height: 35,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: FaIcon(
                    FontAwesomeIcons.magnifyingGlass,
                    size: 18,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ),
            );
          },
        ),
        InkWell(
          onTap: () {
            final vocabState = context.read<VocabularyBloc>().state;
            List<VocabularyItem> allItems = [];
            if (vocabState is VocabularyLoaded) {
              allItems = vocabState.items;
            }
            HomeDialogs.showStatsDialog(
              context,
              user,
              allItems,
              LanguageHelper.availableLanguages,
            );
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.auto_graph_rounded,
              size: 20,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(
            right: 16,
            top: 12,
            bottom: 12,
            left: 6,
          ),
          child: Center(
            child: InkWell(
              onTap: () {
                if (!isPremium) {
                  showDialog(
                    context: context,
                    builder: (context) => const PremiumLockDialog(),
                  ).then((unlocked) {
                    if (unlocked == true) {
                      context.read<AuthBloc>().add(AuthCheckRequested());
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Welcome to Premium!"),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  });
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "You are a PRO member!",
                        style: TextStyle(color: Colors.white),
                      ),
                      backgroundColor: Colors.amber,
                      duration: Duration(seconds: 1),
                    ),
                  );
                }
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isPremium
                      ? const Color(0xFFFFC107).withOpacity(0.15)
                      : (isDark ? Colors.white10 : Colors.grey.shade100),
                  border: Border.all(
                    color: isPremium
                        ? const Color(0xFFFFC107)
                        : Colors.grey.shade400,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPremium
                          ? Icons.workspace_premium_rounded
                          : Icons.lock_outline_rounded,
                      size: 18,
                      color: isPremium
                          ? const Color(0xFFFFA000)
                          : (isDark ? Colors.white70 : Colors.grey.shade600),
                    ),
                    if (isPremium) ...[
                      const SizedBox(width: 4),
                      Text(
                        "PRO",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFFFA000),
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGlobalFilterChips(bool isDark) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _globalFilters.length,
        separatorBuilder: (ctx, i) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = _globalFilters[index];
          final isSelected = _selectedGlobalFilter == category;
          return GestureDetector(
            onTap: () => setState(() => _selectedGlobalFilter = category),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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

  Widget _buildAIStoryButton(BuildContext context, bool isDark) {
    final List<Color> gradientColors = isDark
        ? [const Color(0xFFFFFFFF), const Color(0xFFE0E0E0)]
        : [const Color(0xFF2C3E50), const Color(0xFF000000)];
    final Color textColor = isDark ? Colors.black : Colors.white;
    final Color shadowColor = isDark
        ? Colors.white.withOpacity(0.15)
        : Colors.black.withOpacity(0.3);

    return Padding(
      padding: const EdgeInsets.only(left: 16.0, right: 16),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 12,
              offset: const Offset(0, 4),
              spreadRadius: 1,
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: () => HomeUtils.showAIStoryGenerator(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome, color: textColor, size: 20),
              const SizedBox(width: 10),
              Text(
                "Personalized Story Lesson",
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilteredList(
    List<LessonModel> lessons,
    Map<String, VocabularyItem> vocabMap,
    bool isDark,
  ) {
    final filtered = lessons.where((l) {
      if (_selectedGlobalFilter == 'Videos')
        return l.type == 'video' || l.type == 'video_native';
      if (_selectedGlobalFilter == 'Audio') return l.type == 'audio';
      if (_selectedGlobalFilter == 'Text') return l.type == 'text';
      return true;
    }).toList();

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: filtered.length,
      separatorBuilder: (ctx, i) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final lesson = filtered[index];
        if (lesson.type == 'text') {
          return TextLessonCard(
            lesson: lesson,
            vocabMap: vocabMap,
            isDark: isDark,
            onTap: () => _handleLessonTap(lesson),
            onOptionTap: () => showLessonOptions(context, lesson, isDark),
          );
        } else {
          return Center(
            child: SizedBox(
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: VideoLessonCard(
                  lesson: lesson,
                  vocabMap: vocabMap,
                  isDark: isDark,
                  onTap: () => _handleLessonTap(lesson),
                  onOptionTap: () => showLessonOptions(context, lesson, isDark),
                ),
              ),
            ),
          );
        }
      },
    );
  }

  void _handleLessonTap(LessonModel lesson) {
    final audioManager = AudioGlobalManager();
    if (lesson.userId == 'system_librivox') {
      audioManager.playLesson(lesson);
      return;
    } else {
      if (audioManager.isPlaying || audioManager.currentLesson != null) {
        audioManager.stopAndClose();
      }
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ReaderScreen(lesson: lesson)),
      );
    }
  }
}
