import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/services/lesson_cache_service.dart';
import 'package:linguaflow/screens/playlist/playlist_player_screen.dart';

class PlaylistOpenButton extends StatelessWidget {
  final String playlistName;
  final String playlistId;
  final List<dynamic> lessonIds; // IDs stored in the playlist document
  final String
  currentUserId; // Needed to fetch lesson details from user's collection
  final bool isDark;

  const PlaylistOpenButton({
    super.key,
    required this.playlistName,
    required this.playlistId,
    required this.lessonIds,
    required this.currentUserId,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    // Theme Colors
    final buttonColor = isDark ? const Color(0xFF6C63FF) : Colors.blueAccent;
    final surfaceColor = isDark ? const Color(0xFF2C2C2C) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showPlaylistSheet(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                // Icon Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: buttonColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.playlist_play_rounded,
                    color: buttonColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),

                // Text Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                        playlistName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: Text(
                          "${lessonIds.length} Lessons",
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Arrow
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: isDark ? Colors.grey[600] : Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPlaylistSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PlaylistContentSheet(
        playlistName: playlistName,
        playlistId: playlistId,
        lessonIds: lessonIds,
        userId: currentUserId,
        isDark: isDark,
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// INTERNAL WIDGET: The Bottom Sheet Content
// -----------------------------------------------------------------------------

class _PlaylistContentSheet extends StatefulWidget {
  final String playlistName;
  final String playlistId;
  final List<dynamic> lessonIds;
  final String userId;
  final bool isDark;

  const _PlaylistContentSheet({
    required this.playlistName,
    required this.playlistId,
    required this.lessonIds,
    required this.userId,
    required this.isDark,
  });

  @override
  State<_PlaylistContentSheet> createState() => _PlaylistContentSheetState();
}

class _PlaylistContentSheetState extends State<_PlaylistContentSheet> {
  late Future<List<LessonModel>> _lessonsFuture;

  // Local cache of loaded lessons to pass to the player immediately
  List<LessonModel> _loadedLessons = [];

  @override
  void initState() {
    super.initState();
    _lessonsFuture = _fetchLessons();
  }

  Future<List<LessonModel>> _fetchLessons() async {
    if (widget.lessonIds.isEmpty) return [];

    List<LessonModel> finalResults = [];
    List<String> missingIds = [];

    // ---------------------------------------------------------
    // STEP 1: Check Local Cache (SharedPreferences)
    // ---------------------------------------------------------
    final cacheService = LessonCacheService();
    final List<String> targetIds = widget.lessonIds
        .map((e) => e.toString())
        .toSet()
        .toList();

    for (String id in targetIds) {
      final cachedLesson = await cacheService.getLesson(id);
      if (cachedLesson != null) {
        finalResults.add(cachedLesson);
      } else {
        missingIds.add(id);
      }
    }

    // If we found everything locally, return immediately!
    if (missingIds.isEmpty) {
      // Re-order based on playlist order
      return _orderLessons(finalResults, targetIds);
    }

    // ---------------------------------------------------------
    // STEP 2: Fetch Missing IDs from Firestore
    // ---------------------------------------------------------
    List<LessonModel> fetchedFromCloud = [];
    final List<String> foundCloudIds = [];

    // Helper to process chunks (Firestore 'whereIn' limit is 10)
    Future<void> fetchChunk(
      List<String> chunk,
      CollectionReference collection,
    ) async {
      try {
        final snapshot = await collection
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        for (var doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final lesson = LessonModel.fromMap(data, doc.id);

          fetchedFromCloud.add(lesson);
          foundCloudIds.add(doc.id);

          // IMPORTANT: Cache this new lesson for next time!
          await cacheService.cacheLesson(lesson);
        }
      } catch (e) {
        debugPrint("Error fetching chunk from ${collection.path}: $e");
      }
    }

    // A. Check Personal Library for missing IDs
    for (var i = 0; i < missingIds.length; i += 10) {
      final end = (i + 10 < missingIds.length) ? i + 10 : missingIds.length;
      final chunk = missingIds.sublist(i, end);

      await fetchChunk(
        chunk,
        FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .collection('lessons'),
      );
    }

    // B. Check Global/Public Collection for whatever is STILL missing
    final stillMissing = missingIds
        .where((id) => !foundCloudIds.contains(id))
        .toList();
    if (stillMissing.isNotEmpty) {
      for (var i = 0; i < stillMissing.length; i += 10) {
        final end = (i + 10 < stillMissing.length)
            ? i + 10
            : stillMissing.length;
        final chunk = stillMissing.sublist(i, end);

        await fetchChunk(
          chunk,
          FirebaseFirestore.instance.collection('lessons'),
        );
      }
    }

    // Combine Local Results + Cloud Results
    finalResults.addAll(fetchedFromCloud);

    // Return ordered list
    return _orderLessons(finalResults, targetIds);
  }

  // Helper to maintain playlist order
  List<LessonModel> _orderLessons(
    List<LessonModel> unsorted,
    List<String> orderIds,
  ) {
    final Map<String, LessonModel> map = {for (var l in unsorted) l.id: l};
    List<LessonModel> ordered = [];
    for (String id in orderIds) {
      if (map.containsKey(id)) {
        ordered.add(map[id]!);
      }
    }
    return ordered;
  }

  Future<void> _removeFromPlaylist(String lessonId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('playlists')
          .doc(widget.playlistId)
          .update({
            'lessonIds': FieldValue.arrayRemove([lessonId]),
          });

      // Update local UI
      setState(() {
        widget.lessonIds.remove(lessonId);
        _lessonsFuture = _fetchLessons(); // Refetch to clean list
      });
    } catch (e) {
      debugPrint("Error removing: $e");
    }
  }

  // --- NAVIGATION LOGIC ---
  void _openPlayer(int initialIndex) {
    if (_loadedLessons.isEmpty) return;

    // Close the bottom sheet
    Navigator.pop(context);

    // Open the Player Screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PlaylistPlayerScreen(
          playlist: _loadedLessons,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final cardColor = widget.isDark
        ? const Color(0xFF2C2C2C)
        : Colors.grey[100];
    final textColor = widget.isDark ? Colors.white : Colors.black87;
    final subTextColor = widget.isDark ? Colors.grey[400] : Colors.grey[600];

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // --- HANDLE ---
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // --- HEADER ---
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 0,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.playlistName,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),
                    // PLAY ALL BUTTON (Header)
                    if (widget.lessonIds.isNotEmpty)
                      FloatingActionButton.small(
                        backgroundColor: widget.isDark
                            ? const Color(0xFF6C63FF)
                            : Colors.blueAccent,
                        onPressed: () {
                          if (_loadedLessons.isNotEmpty) {
                            _openPlayer(0);
                          }
                        },
                        child: const Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Divider(height: 1, color: Colors.grey.withOpacity(0.2)),

              // --- CONTENT ---
              Expanded(
                child: FutureBuilder<List<LessonModel>>(
                  future: _lessonsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final lessons = snapshot.data ?? [];

                    // Capture lessons for the Play Button to use
                    _loadedLessons = lessons;

                    if (lessons.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.playlist_remove,
                              size: 64,
                              color: subTextColor,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "Playlist is empty",
                              style: TextStyle(color: subTextColor),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: lessons.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final lesson = lessons[index];
                        return _buildLessonItem(
                          lesson,
                          cardColor!,
                          textColor,
                          subTextColor,
                          index,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLessonItem(
    LessonModel lesson,
    Color cardBg,
    Color txtColor,
    Color? subTxtColor,
    int index,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        // Thumbnail
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 60,
            height: 60, // Square aspect ratio
            color: Colors.grey[800],
            child: lesson.imageUrl != null && lesson.imageUrl!.isNotEmpty
                ? Image.network(lesson.imageUrl!, fit: BoxFit.cover)
                : Icon(
                    lesson.type == 'video'
                        ? Icons.videocam
                        : lesson.type == 'audio'
                        ? Icons.audiotrack
                        : Icons.article,
                    color: Colors.white54,
                    size: 20,
                  ),
          ),
        ),
        // Title & Info
        title: Text(
          lesson.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: txtColor,
          ),
        ),
        subtitle: Row(
          children: [
            // Language badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                lesson.language.toUpperCase(),
                style: const TextStyle(fontSize: 10, color: Colors.white70),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              lesson.difficulty,
              style: TextStyle(fontSize: 12, color: subTxtColor),
            ),
          ],
        ),
        // Remove Action
        trailing: IconButton(
          icon: Icon(Icons.remove_circle_outline, color: Colors.red[300]),
          onPressed: () => _removeFromPlaylist(lesson.id),
        ),
        onTap: () {
          // Play specific lesson
          _openPlayer(index);
        },
      ),
    );
  }
}
