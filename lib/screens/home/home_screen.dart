import 'dart:async'; // Required for StreamSubscription
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart'; // NEW

import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/lesson/lesson_bloc.dart';
import 'package:linguaflow/blocs/vocabulary/vocabulary_bloc.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/models/vocabulary_item.dart';
import 'package:linguaflow/screens/home/widgets/audio_player_overlay.dart';
import 'package:linguaflow/screens/home/widgets/audio_section.dart';
import 'package:linguaflow/screens/reader/reader_screen.dart';
import 'package:linguaflow/screens/home/widgets/home_dialogs.dart'; 
import 'package:linguaflow/screens/home/widgets/home_language_dialogs.dart';
import 'package:linguaflow/screens/home/widgets/home_sections.dart';
import 'package:linguaflow/screens/home/widgets/lesson_cards.dart';
import 'package:linguaflow/screens/home/utils/home_utils.dart';
import 'package:linguaflow/utils/language_helper.dart'; 
import 'package:linguaflow/widgets/premium_lock_dialog.dart';
import 'package:linguaflow/services/web_scraper_service.dart'; // NEW: Ensure this file exists

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
  late StreamSubscription _intentDataStreamSubscription; // NEW

  @override
  void initState() {
    super.initState();
    // Initialize Share Listener immediately
    _initShareListener(); // NEW

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated) {
        final user = authState.user;
        
        if (user.currentLanguage.isEmpty) {
          HomeLanguageDialogs.showNativeLanguageSelector(context, isFirstSetup: true);
        } else if (user.nativeLanguage.isEmpty) {
           HomeLanguageDialogs.showNativeLanguageSelector(context, isFirstSetup: false);
        } else {
          context.read<VocabularyBloc>().add(VocabularyLoadRequested(user.id));
        }
      }
    });
  }

  @override
  void dispose() {
    _intentDataStreamSubscription.cancel(); // NEW: Cleanup listener
    super.dispose();
  }

  // --- NEW: SHARE LISTENER LOGIC ---
  void _initShareListener() {
    // 1. Listen for sharing while app is running (in memory)
    _intentDataStreamSubscription = ReceiveSharingIntent.instance.getMediaStream().listen((List<SharedMediaFile> value) {
      if (value.isNotEmpty && value.first.path.isNotEmpty) {
        // Usually text comes as path for getTextStream, but check package version logic
        // If using latest 1.8.x+, getTextStream is deprecated in favor of getMediaStream 
        // or specifically tailored text streams depending on version.
        // Assuming older version or standard text approach:
        _handleSharedContent(value.first.path); 
      }
    }, onError: (err) {
      debugPrint("getMediaStream error: $err");
    });

    // NOTE: If using receive_sharing_intent < 1.6.0 use getTextStream
    // Since I don't know your exact version, I'll add the most common text listener:
    // UNCOMMENT IF COMPILER COMPLAINS ABOUT getMediaStream FOR TEXT
    /*
    _intentDataStreamSubscription = ReceiveSharingIntent.getTextStream().listen((String value) {
      _handleSharedContent(value);
    }, onError: (err) => print("getLinkStream error: $err"));
    
    ReceiveSharingIntent.getInitialText().then((String? value) {
      if (value != null) _handleSharedContent(value);
    });
    */
    
    // For modern versions supporting both:
    // Try catching initial share if app was closed
    ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> value) {
        if (value.isNotEmpty && value.first.path.isNotEmpty) {
             _handleSharedContent(value.first.path);
        }
    });
  }

  Future<void> _handleSharedContent(String sharedText) async {
    if (!mounted) return;
    
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return; // Ignore if not logged in
    final user = authState.user;

    // Check if URL
    final uri = Uri.tryParse(sharedText);
    bool isUrl = uri != null && (uri.scheme == 'http' || uri.scheme == 'https');

    String initialTitle = "";
    String initialContent = "";

    if (isUrl) {
      // Show loading spinner while scraping
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => const Center(child: CircularProgressIndicator()),
      );

      final data = await WebScraperService.scrapeUrl(sharedText);
      
      if (!mounted) return;
      Navigator.pop(context); // Hide spinner

      if (data != null) {
        initialTitle = data['title']!;
        initialContent = data['content']!;
      } else {
        initialContent = sharedText; // Fallback
      }
    } else {
      initialContent = sharedText;
    }

    if (!mounted) return;

    // Open your existing Create Dialog, pre-filled
    HomeDialogs.showCreateLessonDialog(
      context,
      user.id,
      user.currentLanguage,
      LanguageHelper.availableLanguages, 
      isFavoriteByDefault: false,
      initialTitle: initialTitle,     // NEW param
      initialContent: initialContent, // NEW param
    );
  }
  // ---------------------------------

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

    if (user.currentLanguage.isEmpty) {
      return Scaffold(
        backgroundColor: bgColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.translate, size: 64, color: Colors.grey.withOpacity(0.5)),
              const SizedBox(height: 16),
              const Text("Welcome! Setting up...", style: TextStyle(fontSize: 16)),
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
                vocabMap = {for (var item in vocabState.items) item.word.toLowerCase(): item};
              }

              return Column(
                children: [
                  _buildGlobalFilterChips(isDark),
                  Expanded(
                    child: BlocBuilder<LessonBloc, LessonState>(
                      builder: (context, lessonState) {
                        if (lessonState is LessonInitial) {
                          if (user.currentLanguage.isNotEmpty) {
                            context.read<LessonBloc>().add(LessonLoadRequested(user.id, user.currentLanguage));
                          }
                          return const Center(child: CircularProgressIndicator());
                        }
                        
                        if (lessonState is LessonLoading || lessonState is LessonGenerationSuccess) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        if (lessonState is LessonLoaded) {
                          var processedLessons = lessonState.lessons;

                          if (_selectedGlobalFilter != 'All') {
                            return _buildFilteredList(processedLessons, vocabMap, isDark);
                          }

                          final nativeLessons = processedLessons.where((l) => l.type == 'video_native').toList();
                          final guidedLessons = processedLessons.where((l) => l.type == 'video').toList();
                          final audioLessons = processedLessons.where((l) => l.type == 'audio').toList();
                          final libraryLessons = processedLessons.where((l) => l.type == 'text' && l.userId.startsWith('system')).toList();
                          final importedLessons = processedLessons.where((l) => l.type == 'text' && !l.userId.startsWith('system')).toList();

                          return RefreshIndicator(
                            onRefresh: () async {
                              context.read<LessonBloc>().add(LessonLoadRequested(user.id, user.currentLanguage));
                              context.read<VocabularyBloc>().add(VocabularyLoadRequested(user.id));
                            },
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.only(bottom: 120),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  GuidedCoursesSection(
                                    guidedLessons: guidedLessons,
                                    importedLessons: importedLessons,
                                    vocabMap: vocabMap,
                                    isDark: isDark,
                                  ),
                                  _buildAIStoryButton(context, isDark),
                                  ImmersionSection(lessons: nativeLessons, vocabMap: vocabMap, isDark: isDark),
                                  if (audioLessons.isNotEmpty)
                                    AudioLibrarySection(lessons: audioLessons, isDark: isDark),
                                  LibrarySection(lessons: libraryLessons, vocabMap: vocabMap, isDark: isDark),
                                ],
                              ),
                            ),
                          );
                        }
                        return const Center(child: Text('Something went wrong'));
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
              onTap: () => HomeDialogs.showCreateLessonDialog(
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
  PreferredSizeWidget _buildAppBar(BuildContext context, dynamic user, bool isDark, Color? textColor) {
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
            knownCount = vocabState.items.where((v) => v.status > 0 && v.language == user.currentLanguage).length;
          }
          final String currentLevel = user.currentLevel;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => HomeLanguageDialogs.showTargetLanguageSelector(context),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300, width: 2),
                    color: isDark ? Colors.black26 : Colors.white,
                  ),
                  alignment: Alignment.center,
                  child: Text(LanguageHelper.getFlagEmoji(user.currentLanguage), style: const TextStyle(fontSize: 28)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: InkWell(
                  onTap: () => HomeLanguageDialogs.showLevelSelector(context, currentLevel, user.currentLanguage),
                  borderRadius: BorderRadius.circular(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              currentLevel,
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor, letterSpacing: 0.5),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: isDark ? Colors.white54 : Colors.grey.shade600),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, size: 18, color: Color(0xFFFFC107)),
                          const SizedBox(width: 6),
                          Text(
                            "$knownCount / ${_getNextGoal(knownCount)} words",
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Center(
            child: InkWell(
              onTap: () {
                if (!isPremium) {
                  showDialog(context: context, builder: (context) => const PremiumLockDialog()).then((unlocked) {
                    if (unlocked == true) {
                      context.read<AuthBloc>().add(AuthCheckRequested());
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Welcome to Premium!"), backgroundColor: Colors.green));
                    }
                  });
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("You are a PRO member!", style: TextStyle(color: Colors.white)), backgroundColor: Colors.amber, duration: Duration(seconds: 1)));
                }
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isPremium ? const Color(0xFFFFC107).withOpacity(0.15) : (isDark ? Colors.white10 : Colors.grey.shade100),
                  border: Border.all(color: isPremium ? const Color(0xFFFFC107) : Colors.grey.shade400, width: 1.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(isPremium ? Icons.workspace_premium_rounded : Icons.lock_outline_rounded, size: 18, color: isPremium ? const Color(0xFFFFA000) : (isDark ? Colors.white70 : Colors.grey.shade600)),
                    if (isPremium) ...[
                      const SizedBox(width: 4),
                      Text("PRO", style: TextStyle(fontWeight: FontWeight.w900, color: const Color(0xFFFFA000), fontSize: 12, letterSpacing: 0.5)),
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

  int _getNextGoal(int count) {
    if (count < 500) return 500;
    if (count < 1000) return 1000;
    if (count < 2000) return 2000;
    if (count < 4000) return 4000;
    if (count < 8000) return 8000;
    return 16000;
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
                color: isSelected ? (isDark ? Colors.white : Colors.black) : (isDark ? Colors.white10 : Colors.grey[100]),
                borderRadius: BorderRadius.circular(20),
                border: isSelected ? null : Border.all(color: isDark ? Colors.transparent : Colors.grey.shade300),
              ),
              alignment: Alignment.center,
              child: Text(category, style: TextStyle(color: isSelected ? (isDark ? Colors.black : Colors.white) : (isDark ? Colors.white70 : Colors.black), fontWeight: FontWeight.w600)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAIStoryButton(BuildContext context, bool isDark) {
    final List<Color> gradientColors = isDark ? [const Color(0xFFFFFFFF), const Color(0xFFE0E0E0)] : [const Color(0xFF2C3E50), const Color(0xFF000000)];
    final Color textColor = isDark ? Colors.black : Colors.white;
    final Color shadowColor = isDark ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.3);

    return Padding(
      padding: const EdgeInsets.only(left: 16.0, right: 16),
      child: Container(
        decoration: BoxDecoration(gradient: LinearGradient(colors: gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: shadowColor, blurRadius: 12, offset: const Offset(0, 4), spreadRadius: 1)]),
        child: ElevatedButton(
          onPressed: () => HomeUtils.showAIStoryGenerator(context),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome, color: textColor, size: 20),
              const SizedBox(width: 10),
              Text("Personalized Story Lesson", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilteredList(List<LessonModel> lessons, Map<String, VocabularyItem> vocabMap, bool isDark) {
    final filtered = lessons.where((l) {
      if (_selectedGlobalFilter == 'Videos') return l.type == 'video' || l.type == 'video_native';
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
          return TextLessonCard(lesson: lesson, vocabMap: vocabMap, isDark: isDark, onTap: () => _handleLessonTap(lesson), onOptionTap: () => HomeDialogs.showLessonOptions(context, lesson, isDark));
        } else {
          return Center(child: SizedBox(width: double.infinity, child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.center, child: VideoLessonCard(lesson: lesson, vocabMap: vocabMap, isDark: isDark, onTap: () => _handleLessonTap(lesson), onOptionTap: () => HomeDialogs.showLessonOptions(context, lesson, isDark)))));
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
      Navigator.push(context, MaterialPageRoute(builder: (context) => ReaderScreen(lesson: lesson)));
    }
  }
}