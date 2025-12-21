import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_state.dart';
// 1. IMPORT YOUR CONSTANTS
import 'package:linguaflow/constants/genre_constants.dart';
import 'package:linguaflow/screens/home/widgets/build_appbar.dart';
import 'package:linguaflow/screens/home/widgets/sections/filtered_generated_list.dart';
import 'package:linguaflow/screens/home/widgets/sections/genre_feed_section.dart';
import 'package:linguaflow/screens/home/widgets/sections/guided_courses_section.dart';
import 'package:linguaflow/screens/home/widgets/sections/immersion_section.dart';
import 'package:linguaflow/screens/home/widgets/sections/library_section.dart';
import 'package:linguaflow/utils/utils.dart';
import 'package:linguaflow/widgets/buttons/build_ai_button.dart';
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
import 'package:linguaflow/screens/home/widgets/audio_section.dart';
import 'package:linguaflow/screens/home/widgets/lesson_cards.dart';
import 'package:linguaflow/screens/home/widgets/audio_player_overlay.dart';
import 'package:linguaflow/screens/home/widgets/home_language_dialogs.dart';
import 'package:linguaflow/widgets/lesson_import_dialog.dart';

// SCREENS
import 'package:linguaflow/screens/reader/reader_screen.dart';

// UTILS
import 'package:linguaflow/screens/home/utils/home_utils.dart';
import 'package:linguaflow/utils/language_helper.dart';
import 'package:linguaflow/services/web_scraper_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // --- TYPE FILTERS ---
  String _selectedGlobalFilter = 'All';
  final List<String> _globalFilters = ['All', 'Videos', 'Audio', 'Text'];

  // --- DESKTOP SPECIFIC FILTERS ---
  String _selectedDifficulty = 'All';
  String _selectedGenre = 'All'; // This stores the VALUE (e.g. "science")
  String _selectedSort = 'Newest';

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
      if (host.contains('youtube.com') || host.contains('youtu.be')) {
        isYoutube = true;
      }
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
                color: Colors.grey.withValues(alpha: 0.5),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth > 800;
        return Scaffold(
          backgroundColor: bgColor,
          appBar: buildAppBar(context, user, isDark, textColor, isDesktop),
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
                      _buildGlobalFilterChips(isDark, isDesktop),

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

                              // --- 1. SPECIAL CASE: GENRE FILTER ---
                              // If a specific genre is selected, we bypass the local filtering
                              // and use the specialized fetcher widget.
                              if (_selectedGenre != 'All') {
                                return FilteredGenreList(
                                  genreKey: _selectedGenre,
                                  languageCode: currentLangCode,
                                  vocabMap: vocabMap,
                                  isDark: isDark,
                                  isDesktop: isDesktop,
                                );
                              }

                              // --- 2. LOCAL FILTERING (For Type, Difficulty, Sort) ---
                              // This logic works fine locally because types usually exist in the feed
                              bool isFiltering =
                                  _selectedGlobalFilter != 'All' ||
                                  _selectedDifficulty != 'All';

                              if (isFiltering) {
                                return _buildFilteredList(
                                  processedLessons, // Only filters the 20 loaded items
                                  vocabMap,
                                  isDark,
                                  isDesktop,
                                );
                              }

                              // --- DASHBOARD MODE (Horizontal Sections) ---
                              final nativeLessons = processedLessons
                                  .where((l) => l.userId == 'system_native')
                                  .toList();
                              final guidedLessons = processedLessons
                                  .where((l) => l.userId == 'system')
                                  .toList();
                              final audioLessons = processedLessons
                                  .where((l) => l.type == 'audio')
                                  .toList();
                              final libraryLessons = processedLessons
                                  .where(
                                    (l) =>
                                        l.type == 'text' &&
                                        (l.userId == 'system_gutenberg' ||
                                            l.userId == 'system_beginner' ||
                                            l.userId == 'system_storybooks'),
                                  )
                                  .toList();
                              final importedLessons = processedLessons
                                  .where((l) => !l.userId.startsWith('system'))
                                  .toList();

                              return RefreshIndicator(
                                onRefresh: () async {
                                  context.read<LessonBloc>().add(
                                    LessonLoadRequested(
                                      user.id,
                                      user.currentLanguage,
                                      forceRefresh: true,
                                    ),
                                  );
                                  context.read<VocabularyBloc>().add(
                                    VocabularyLoadRequested(user.id),
                                  );
                                },
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.only(bottom: 120),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      GuidedCoursesSection(
                                        languageCode: currentLangCode,
                                        guidedLessons: guidedLessons,
                                        importedLessons: importedLessons,
                                        vocabMap: vocabMap,
                                        isDark: isDark,
                                      ),

                                      if (!isDesktop)
                                        buildAIStoryButton(context, isDark),

                                      ImmersionSection(
                                        languageCode: currentLangCode,
                                        lessons: nativeLessons,
                                        vocabMap: vocabMap,
                                        isDark: isDark,
                                      ),

                                      if (audioLessons.isNotEmpty)
                                        AudioLibrarySection(
                                          lessons: audioLessons,
                                          isDark: isDark,
                                        ),

                                      LibrarySection(
                                        languageCode: currentLangCode,
                                        lessons: libraryLessons,
                                        vocabMap: vocabMap,
                                        isDark: isDark,
                                      ),
                                      // Dynamic Genre Feeds from Constants
                                      ...GenreConstants.categoryMap.entries.map(
                                        (entry) {
                                          return GenreFeedSection(
                                            title: entry.key,
                                            genreKey: entry.value,
                                            languageCode: currentLangCode,
                                            vocabMap: vocabMap,
                                            isDark: isDark,
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 30),
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
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
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
      },
    );
  }

  Widget _buildGlobalFilterChips(bool isDark, bool isDesktop) {
    if (!isDesktop) {
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
            return _buildChip(
              label: category,
              isSelected: isSelected,
              isDark: isDark,
              onTap: () => setState(() => _selectedGlobalFilter = category),
            );
          },
        ),
      );
    }

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: Row(
        children: [
          ..._globalFilters.map((category) {
            final isSelected = _selectedGlobalFilter == category;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: _buildChip(
                label: category,
                isSelected: isSelected,
                isDark: isDark,
                onTap: () => setState(() => _selectedGlobalFilter = category),
              ),
            );
          }),

          const Spacer(),

          _buildDesktopDropdownFilter(
            label: "Difficulty",
            value: _selectedDifficulty,
            options: ['All', 'beginner', 'intermediate', 'advanced'],
            isDark: isDark,
            onChanged: (val) => setState(() => _selectedDifficulty = val),
          ),
          const SizedBox(width: 10),

          // --- FIXED GENRE DROPDOWN ---
          _buildGenreDropdown(isDark),

          const SizedBox(width: 10),

          _buildDesktopDropdownFilter(
            label: "Sort",
            value: _selectedSort,
            options: ['Newest', 'Oldest'],
            isDark: isDark,
            onChanged: (val) => setState(() => _selectedSort = val),
            icon: Icons.sort_rounded,
          ),
        ],
      ),
    );
  }

  // --- 1. ROBUST GENRE DROPDOWN ---
  Widget _buildGenreDropdown(bool isDark) {
    String displayTitle = "Genre";
    if (_selectedGenre != 'All') {
      // Find the Display Title (Key) for the selected Internal Value
      final entry = GenreConstants.categoryMap.entries.firstWhere(
        (e) => e.value == _selectedGenre,
        orElse: () => MapEntry(_selectedGenre.capitalize(), _selectedGenre),
      );
      displayTitle = entry.key;
    }

    final bool isActive = _selectedGenre != 'All';

    return PopupMenuButton<String>(
      tooltip: "Filter by Genre",
      onSelected: (val) => setState(() => _selectedGenre = val),
      itemBuilder: (BuildContext context) {
        List<PopupMenuEntry<String>> menuItems = [];

        // Add "All"
        menuItems.add(
          PopupMenuItem<String>(
            value: 'All',
            child: _buildPopupItemRow('All', _selectedGenre == 'All'),
          ),
        );

        // Add Categories from GenreConstants
        menuItems.addAll(
          GenreConstants.categoryMap.entries.map((entry) {
            return PopupMenuItem<String>(
              value: entry.value, // We store the internal value "science"
              child: _buildPopupItemRow(
                entry.key, // We display "Science & Knowledge"
                _selectedGenre == entry.value,
              ),
            );
          }),
        );

        return menuItems;
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? (isDark
                    ? Colors.blue.withOpacity(0.2)
                    : Colors.blue.withOpacity(0.1))
              : (isDark ? Colors.white10 : Colors.grey[100]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? Colors.blue
                : (isDark ? Colors.transparent : Colors.grey.shade300),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              displayTitle,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isActive
                    ? Colors.blue
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              color: isActive
                  ? Colors.blue
                  : (isDark ? Colors.white54 : Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopDropdownFilter({
    required String label,
    required String value,
    required List<String> options,
    required bool isDark,
    required Function(String) onChanged,
    IconData? icon,
  }) {
    final bool isActive = value != 'All' && value != 'Newest';

    return PopupMenuButton<String>(
      tooltip: "Filter by $label",
      onSelected: onChanged,
      itemBuilder: (BuildContext context) {
        return options.map((String choice) {
          return PopupMenuItem<String>(
            value: choice,
            child: _buildPopupItemRow(choice.capitalize(), choice == value),
          );
        }).toList();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? (isDark
                    ? Colors.blue.withOpacity(0.2)
                    : Colors.blue.withOpacity(0.1))
              : (isDark ? Colors.white10 : Colors.grey[100]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? Colors.blue
                : (isDark ? Colors.transparent : Colors.grey.shade300),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              isActive ? value.capitalize() : label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isActive
                    ? Colors.blue
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              color: isActive
                  ? Colors.blue
                  : (isDark ? Colors.white54 : Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPopupItemRow(String text, bool isSelected) {
    return Row(
      children: [
        if (isSelected)
          const Icon(Icons.check, size: 16, color: Colors.blue)
        else
          const SizedBox(width: 16),
        const SizedBox(width: 8),
        Text(text),
      ],
    );
  }

  Widget _buildChip({
    required String label,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
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
                  color: isDark ? Colors.transparent : Colors.grey.shade300,
                ),
        ),
        alignment: Alignment.center,
        child: Text(
          label.capitalize(),
          style: TextStyle(
            color: isSelected
                ? (isDark ? Colors.black : Colors.white)
                : (isDark ? Colors.white70 : Colors.black),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // --- 2. ROBUST GENRE MATCHING LOGIC ---
  bool _matchesGenre(LessonModel lesson, String selectedGenreKey) {
    if (selectedGenreKey == 'All') return true;

    final lessonGenre = lesson.genre.trim().toLowerCase();
    final filterKey = selectedGenreKey.toLowerCase(); // e.g., "science"

    // 1. Direct match with the key (e.g. lesson="science" == filter="science")
    if (lessonGenre == filterKey) return true;

    // 2. Direct match with the Display Title (e.g. lesson="Science & Knowledge")
    // Find the Display Title corresponding to the filterKey
    String? displayTitle;
    for (var entry in GenreConstants.categoryMap.entries) {
      if (entry.value.toLowerCase() == filterKey) {
        displayTitle = entry.key.toLowerCase();
        break;
      }
    }

    // Check if the lesson genre matches the display title
    if (displayTitle != null && lessonGenre == displayTitle) return true;

    return false;
  }

  Widget _buildFilteredList(
    List<LessonModel> lessons,
    Map<String, VocabularyItem> vocabMap,
    bool isDark,
    bool isDesktop,
  ) {
    final filtered = lessons.where((l) {
      // Type Filter
      if (_selectedGlobalFilter == 'Videos' &&
          !(l.type == 'video' || l.type == 'video_native'))
        return false;
      if (_selectedGlobalFilter == 'Audio' && l.type != 'audio') return false;
      if (_selectedGlobalFilter == 'Text' && l.type != 'text') return false;

      // Difficulty Filter
      if (_selectedDifficulty != 'All' &&
          l.difficulty.toLowerCase() != _selectedDifficulty.toLowerCase()) {
        return false;
      }

      // Genre Filter (ROBUST MATCHING)
      if (!_matchesGenre(l, _selectedGenre)) {
        return false;
      }

      return true;
    }).toList();

    // Sorting
    if (_selectedSort == 'Newest') {
      filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } else {
      filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.filter_list_off, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              "No lessons match your filters",
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedGlobalFilter = 'All';
                  _selectedDifficulty = 'All';
                  _selectedGenre = 'All';
                });
              },
              child: const Text("Clear Filters"),
            ),
          ],
        ),
      );
    }

    if (isDesktop) {
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 400,
          mainAxisExtent: 280,
          crossAxisSpacing: 24,
          mainAxisSpacing: 24,
        ),
        itemCount: filtered.length,
        itemBuilder: (context, index) =>
            _buildCard(filtered[index], vocabMap, isDark),
      );
    } else {
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: filtered.length,
        separatorBuilder: (ctx, i) => const SizedBox(height: 16),
        itemBuilder: (context, index) =>
            _buildCard(filtered[index], vocabMap, isDark),
      );
    }
  }

  Widget _buildCard(
    LessonModel lesson,
    Map<String, VocabularyItem> vocabMap,
    bool isDark,
  ) {
    if (lesson.type == 'text') {
      return TextLessonCard(
        lesson: lesson,
        vocabMap: vocabMap,
        isDark: isDark,
        onTap: () => _handleLessonTap(lesson),
        onOptionTap: () => showLessonOptions(context, lesson, isDark),
      );
    } else {
      return VideoLessonCard(
        lesson: lesson,
        vocabMap: vocabMap,
        isDark: isDark,
        onTap: () => _handleLessonTap(lesson),
        onOptionTap: () => showLessonOptions(context, lesson, isDark),
      );
    }
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

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
