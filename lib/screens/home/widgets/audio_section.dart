import 'package:flutter/material.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/screens/home/widgets/audio_player_overlay.dart';
import 'package:linguaflow/screens/reader/reader_screen.dart';
// Add this import for the dialog
import 'package:linguaflow/screens/home/widgets/home_dialogs.dart'; 

class AudioLibrarySection extends StatefulWidget {
  final List<LessonModel> lessons;
  final bool isDark;

  const AudioLibrarySection({
    super.key,
    required this.lessons,
    required this.isDark,
  });

  @override
  _AudioLibrarySectionState createState() => _AudioLibrarySectionState();
}

class _AudioLibrarySectionState extends State<AudioLibrarySection> {
  String _selectedLevel = 'All';
  final List<String> _levels = ['All', 'Beginner', 'Intermediate', 'Advanced'];

  @override
  Widget build(BuildContext context) {
    // 1. Filter Logic
    final filteredLessons = widget.lessons.where((lesson) {
      if (_selectedLevel == 'All') return true;
      return lesson.difficulty.toLowerCase() == _selectedLevel.toLowerCase();
    }).toList();

    // 2. Split Data
    final syncedLessons = filteredLessons
        .where((l) => l.userId == 'system_audiobook')
        .toList();

    final pureAudioLessons = filteredLessons
        .where((l) => l.userId != 'system_audiobook')
        .toList();

    if (syncedLessons.isEmpty && pureAudioLessons.isEmpty) {
      return const SizedBox.shrink();
    }

    final textColor = widget.isDark ? Colors.white : Colors.black;
    final secondaryColor = widget.isDark ? Colors.grey[400] : Colors.grey[600];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Header ---
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            "Audio Library",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ),

        // --- TABS ---
        Container(
          height: 40,
          margin: const EdgeInsets.only(bottom: 10),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: _levels.length,
            separatorBuilder: (ctx, i) => const SizedBox(width: 20),
            itemBuilder: (context, index) {
              final level = _levels[index];
              final isSelected = _selectedLevel == level;

              return GestureDetector(
                onTap: () => setState(() => _selectedLevel = level),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      level,
                      style: TextStyle(
                        color: isSelected ? textColor : secondaryColor,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 3,
                      width: isSelected ? 20 : 0,
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.blue : Colors.transparent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        // --- SECTION 1: READ & LISTEN ---
        if (syncedLessons.isNotEmpty) ...[
          _buildSubHeader("Read & Listen", Icons.subtitles),
          _buildHorizontalList(syncedLessons, isSynced: true),
          const SizedBox(height: 24),
        ],

        // --- SECTION 2: LISTEN ONLY ---
        if (pureAudioLessons.isNotEmpty) ...[
          _buildSubHeader("Podcasts & Stories", Icons.headphones),
          _buildHorizontalList(pureAudioLessons, isSynced: false),
          const SizedBox(height: 24),
        ],
      ],
    );
  }

  Widget _buildSubHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.purple.shade300),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: widget.isDark
                  ? Colors.grey.shade300
                  : Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalList(
    List<LessonModel> lessons, {
    required bool isSynced,
  }) {
    return SizedBox(
      height: 220,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: lessons.length,
        separatorBuilder: (ctx, i) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          return _buildAudioCard(lessons[index], isSynced);
        },
      ),
    );
  }

  Widget _buildAudioCard(LessonModel lesson, bool isSynced) {
    return GestureDetector(
      onTap: () {
        if (isSynced) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReaderScreen(lesson: lesson),
            ),
          );
        } else {
          AudioGlobalManager().playLesson(lesson);
        }
      },
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          color: widget.isDark ? const Color(0xFF2C2C2C) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        // --- CHANGED: Wrapped content in a Stack to overlay the menu button ---
        child: Stack(
          children: [
            // 1. The original content (Image + Text)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image Area
                Expanded(
                  flex: 5,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                        child: lesson.imageUrl != null
                            ? Image.network(lesson.imageUrl!, fit: BoxFit.cover)
                            : Container(
                                color: isSynced
                                    ? Colors.orange.shade100
                                    : Colors.purple.shade100,
                                child: Icon(
                                  isSynced ? Icons.menu_book : Icons.headphones,
                                  color: isSynced ? Colors.orange : Colors.purple,
                                  size: 40,
                                ),
                              ),
                      ),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Text Area
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            lesson.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: widget.isDark ? Colors.white : Colors.black87,
                              height: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (isSynced)
                              Padding(
                                padding: const EdgeInsets.only(right: 4.0),
                                child: Icon(
                                  Icons.abc,
                                  size: 14,
                                  color: Colors.orange.shade400,
                                ),
                              ),
                            Expanded(
                              child: Text(
                                lesson.difficulty,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isSynced
                                      ? Colors.orange.shade400
                                      : Colors.purple.shade400,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // 2. The Menu Button (Bottom Right)
            Positioned(
              bottom: 0,
              right: 0,
              child: Material(
                color: Colors.transparent,
                child: IconButton(
                  icon: const Icon(Icons.more_vert),
                  iconSize: 20,
                  // Subtle color for the icon
                  color: widget.isDark ? Colors.white60 : Colors.grey[500],
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(), // Removes default padding
                  onPressed: () {
                    // Open the options dialog
                    HomeDialogs.showLessonOptions(context, lesson, widget.isDark);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}