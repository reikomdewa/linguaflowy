import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/lesson/lesson_bloc.dart';
import 'package:linguaflow/screens/playlist/widgets/playlist_widgets.dart';
import 'package:linguaflow/screens/library/widgets/dialogs/library_actions.dart';
import 'package:linguaflow/screens/library/widgets/cards/library_text_card.dart';
import 'package:linguaflow/screens/library/widgets/cards/library_video_card.dart';
import 'package:linguaflow/screens/search/library_search_delegate.dart';
// Import the button widget you created

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = (context.watch<AuthBloc>().state as AuthAuthenticated).user;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('My Library'),
        backgroundColor: bgColor,
        elevation: 0,
        foregroundColor: textColor,
        actions: [
          BlocBuilder<LessonBloc, LessonState>(
            builder: (context, state) {
              final bool isLoaded = state is LessonLoaded;

              return Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Center(
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
                      width: 40,
                      height: 40,
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
                ),
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<LessonBloc, LessonState>(
        builder: (context, state) {
          if (state is LessonInitial) {
            context.read<LessonBloc>().add(
              LessonLoadRequested(user.id, user.currentLanguage),
            );
            return const Center(child: CircularProgressIndicator());
          }
          if (state is LessonLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is LessonLoaded) {
            final importedLessons = state.lessons
                .where((l) => l.isLocal)
                .toList();
            final favoriteLessons = state.lessons
                .where((l) => l.isFavorite)
                .toList();

            // We handle empty state inside the ScrollView now to allow Playlists
            // to show up even if lessons are empty, or handle fully empty state if needed.

            return SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- 1. IMPORTED (Horizontal) ---
                  if (importedLessons.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.download_for_offline,
                            color: textColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Imported",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 240,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        scrollDirection: Axis.horizontal,
                        itemCount: importedLessons.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final lesson = importedLessons[index];
                          const double cardWidth = 220;

                          if (lesson.type == 'video' ||
                              (lesson.videoUrl != null &&
                                  lesson.videoUrl!.isNotEmpty)) {
                            return LibraryVideoCard(
                              lesson: lesson,
                              isDark: isDark,
                              width: cardWidth,
                            );
                          } else {
                            return LibraryTextCard(
                              lesson: lesson,
                              isDark: isDark,
                              width: cardWidth,
                            );
                          }
                        },
                      ),
                    ),
                  ],

                  // --- 2. PLAYLISTS (Horizontal Stream) ---
                  _buildPlaylistsSection(
                    context,
                    user.id,
                    isDark,
                    textColor,
                    user.currentLanguage,
                  ),

                  // --- 3. FAVORITES (Vertical) ---
                  if (favoriteLessons.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                      child: Row(
                        children: [
                          Icon(Icons.star, color: Colors.amber[700], size: 20),
                          const SizedBox(width: 8),
                          Text(
                            "Favorites",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ListView.separated(
                      padding: const EdgeInsets.all(16),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: favoriteLessons.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final lesson = favoriteLessons[index];
                        if (lesson.type == 'video' ||
                            (lesson.videoUrl != null &&
                                lesson.videoUrl!.isNotEmpty)) {
                          return LibraryVideoCard(
                            lesson: lesson,
                            isDark: isDark,
                          );
                        } else {
                          return LibraryTextCard(
                            lesson: lesson,
                            isDark: isDark,
                          );
                        }
                      },
                    ),
                  ],

                  // Empty State Fallback if absolutely nothing exists
                  if (importedLessons.isEmpty && favoriteLessons.isEmpty)
                    _buildEmptyStateCheck(user.id, user.currentLanguage),
                ],
              ),
            );
          }
          return const Center(child: Text('Something went wrong'));
        },
      ),

      // --- FAB ---
      floatingActionButton: Material(
        color: Colors.transparent,
        elevation: 10,
        shadowColor: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(30),
        child: InkWell(
          onTap: () {
            showCreateLessonDialog(
              context,
              user.id,
              user.currentLanguage,
              isFavoriteByDefault: false,
            );
          },
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF2C2C2C).withOpacity(0.9)
                  : const Color(0xFF1E1E1E).withOpacity(0.9),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: Colors.white.withOpacity(0.15),
                width: 1,
              ),
            ),
            child: const Row(
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

  // --- PLAYLIST SECTION WIDGET ---
  Widget _buildPlaylistsSection(
    BuildContext context,
    String userId,
    bool isDark,
    Color? textColor,
    String currentLanguage,
  ) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('playlists')
          .where('language', isEqualTo: currentLanguage)
          .orderBy('updatedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final docs = snapshot.data!.docs;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.playlist_play_rounded,
                    color: Colors.blueAccent,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Playlists",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),

            // Horizontal Scroll View for Playlists
            SizedBox(
              height: 120,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final name = data['name'] ?? 'Untitled';
                  final id = docs[index].id;
                  final lessonIds = data['lessonIds'] as List<dynamic>? ?? [];

                  // --- ACTION: Functions to handle Edit and Delete ---
                  void handleEdit() {
                    _showEditPlaylistDialog(context, userId, id, name);
                  }

                  void handleDelete() {
                    _showDeletePlaylistDialog(context, userId, id);
                  }

                  return Center(
                    child: SizedBox(
                      width: 280,
                      // Use a Stack to overlay the Menu Icon on top of the button
                      child: Stack(
                        children: [
                          // 1. The Main Content + Long Press Handler
                          GestureDetector(
                            onLongPress: () {
                              showModalBottomSheet(
                                context: context,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(16),
                                  ),
                                ),
                                builder: (ctx) => SafeArea(
                                  // <--- WRAP IN SAFEAREA
                                  child: Wrap(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          top: 8.0,
                                        ),
                                        child: ListTile(
                                          leading: const Icon(Icons.edit),
                                          title: const Text('Rename Playlist'),
                                          onTap: () {
                                            Navigator.pop(ctx);
                                            handleEdit();
                                          },
                                        ),
                                      ),
                                      ListTile(
                                        leading: const Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                        ),
                                        title: const Text(
                                          'Delete Playlist',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                        onTap: () {
                                          Navigator.pop(ctx);
                                          handleDelete();
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                            child: PlaylistOpenButton(
                              playlistName: name,
                              playlistId: id,
                              lessonIds: lessonIds,
                              currentUserId: userId,
                              isDark: isDark,
                            ),
                          ),

                          // 2. The Menu Icon (Top Right)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Material(
                              color: Colors.transparent,
                              child: PopupMenuButton<String>(
                                icon: Icon(
                                  Icons.more_vert_rounded,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black54,
                                  size: 20,
                                ),
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                onSelected: (value) {
                                  if (value == 'edit') handleEdit();
                                  if (value == 'delete') handleDelete();
                                },
                                itemBuilder: (BuildContext context) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.edit,
                                          size: 18,
                                          color: Colors.blue,
                                        ),
                                        SizedBox(width: 8),
                                        Text('Rename'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.delete_outline,
                                          size: 18,
                                          color: Colors.red,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Delete',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // --- HELPER 1: Edit Dialog ---
  void _showEditPlaylistDialog(
    BuildContext context,
    String userId,
    String playlistId,
    String currentName,
  ) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Rename Playlist"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Enter new name"),
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .collection('playlists')
                    .doc(playlistId)
                    .update({'name': newName});
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  // --- HELPER 2: Delete Dialog ---
  void _showDeletePlaylistDialog(
    BuildContext context,
    String userId,
    String playlistId,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Playlist?"),
        content: const Text(
          "Are you sure you want to delete this playlist? The lessons inside will not be deleted.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .collection('playlists')
                  .doc(playlistId)
                  .delete();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // --- EMPTY STATE CHECKER (Async) ---
  Widget _buildEmptyStateCheck(String userId, String currentLanguage) {
    // <--- Update params
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('playlists')
          .where('language', isEqualTo: currentLanguage) // <--- Filter here too
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        // If loading or we have playlists in this language, show nothing
        if (!snapshot.hasData) return const SizedBox.shrink();
        if (snapshot.data!.docs.isNotEmpty) return const SizedBox.shrink();

        // If NO playlists in this language AND no lessons (parent check), show empty state.
        return Padding(
          padding: const EdgeInsets.only(top: 100),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.auto_stories, size: 80, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  'Library is empty',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Import texts or create playlists.',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
