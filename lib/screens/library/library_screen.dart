import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_state.dart';
import 'package:linguaflow/blocs/lesson/lesson_bloc.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/screens/home/utils/home_utils.dart';
import 'package:linguaflow/screens/playlist/widgets/playlist_widgets.dart';
import 'package:linguaflow/screens/library/widgets/dialogs/library_actions.dart';
import 'package:linguaflow/screens/library/widgets/cards/library_text_card.dart';
import 'package:linguaflow/screens/library/widgets/cards/library_video_card.dart';
import 'package:linguaflow/screens/discover/library_search_delegate.dart';
import 'package:linguaflow/utils/language_helper.dart';
import 'package:linguaflow/widgets/lesson_import_dialog.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = (context.watch<AuthBloc>().state);
    if (authState.isGuest) {
      return Material(
        child: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.person_off, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text("To see your library you have to login"),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.push('/login'),
                  child: const Text("Create Account to Save lessons"),
                ),
              ],
            ),
          ),
        ),
      );
    }
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
            // FILTERING LOGIC
            final importedLessons = state.lessons.where((l) => l.isLocal).toList();
            final cloudLessons = state.lessons.where((l) => !l.isLocal).toList();

            final textLessons = cloudLessons.where((l) {
              bool isVideo = l.type == 'video' || (l.videoUrl != null && l.videoUrl!.isNotEmpty);
              if (isVideo) return false;
              return l.isFavorite || l.type == 'ai_story';
            }).toList();

            final videoLessons = cloudLessons.where((l) {
              bool isVideo = l.type == 'video' || (l.videoUrl != null && l.videoUrl!.isNotEmpty);
              return isVideo && l.isFavorite;
            }).toList();

            return LayoutBuilder(
              builder: (context, constraints) {
                final bool isDesktop = constraints.maxWidth > 900;
                
                // --- DESKTOP VIEW ---
                if (isDesktop) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         // Playlists First on Desktop
                         _buildPlaylistsSection(context, user.id, isDark, textColor, user.currentLanguage),
                         const SizedBox(height: 20),

                         if (importedLessons.isNotEmpty) ...[
                           _buildSectionHeader("Imported Lessons", textColor),
                           _buildDesktopGrid(importedLessons, isDark),
                           const SizedBox(height: 40),
                         ],

                         if (textLessons.isNotEmpty) ...[
                           _buildSectionHeader("Saved Stories", textColor),
                           _buildDesktopGrid(textLessons, isDark),
                           const SizedBox(height: 40),
                         ],

                         if (videoLessons.isNotEmpty) ...[
                           _buildSectionHeader("Favorite Videos", textColor),
                           _buildDesktopGrid(videoLessons, isDark),
                           const SizedBox(height: 100),
                         ],
                         
                         if(importedLessons.isEmpty && textLessons.isEmpty && videoLessons.isEmpty)
                             _buildEmptyStateCheck(user.id, user.currentLanguage),
                      ],
                    ),
                  );
                }

                // --- MOBILE VIEW (Original) ---
                return SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (importedLessons.isNotEmpty) ...[
                        _buildSectionHeader("Imported", textColor, icon: Icons.download_for_offline),
                        SizedBox(
                          height: 240,
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            scrollDirection: Axis.horizontal,
                            itemCount: importedLessons.length,
                            separatorBuilder: (_, _) => const SizedBox(width: 12),
                            itemBuilder: (context, index) {
                              final lesson = importedLessons[index];
                              if (lesson.type == 'video' || (lesson.videoUrl?.isNotEmpty ?? false)) {
                                return LibraryVideoCard(lesson: lesson, isDark: isDark, width: 220);
                              }
                              return LibraryTextCard(lesson: lesson, isDark: isDark, width: 220);
                            },
                          ),
                        ),
                      ],

                      _buildPlaylistsSection(context, user.id, isDark, textColor, user.currentLanguage),

                      if (textLessons.isNotEmpty) ...[
                         _buildSectionHeader("Saved Stories", textColor, icon: Icons.library_books),
                         SizedBox(
                           height: 240,
                           child: ListView.separated(
                             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                             scrollDirection: Axis.horizontal,
                             itemCount: textLessons.length,
                             separatorBuilder: (_, _) => const SizedBox(width: 12),
                             itemBuilder: (context, index) {
                               return LibraryTextCard(lesson: textLessons[index], isDark: isDark, width: 220);
                             },
                           ),
                         ),
                      ],

                      if (videoLessons.isNotEmpty) ...[
                         _buildSectionHeader("Favorite Videos", textColor, icon: Icons.video_library),
                         ListView.separated(
                           padding: const EdgeInsets.all(16),
                           shrinkWrap: true,
                           physics: const NeverScrollableScrollPhysics(),
                           itemCount: videoLessons.length,
                           separatorBuilder: (_, _) => const SizedBox(height: 16),
                           itemBuilder: (context, index) {
                             return LibraryVideoCard(lesson: videoLessons[index], isDark: isDark);
                           },
                         ),
                      ],
                      
                      if (importedLessons.isEmpty && textLessons.isEmpty && videoLessons.isEmpty)
                         _buildEmptyStateCheck(user.id, user.currentLanguage),
                    ],
                  ),
                );
              },
            );
          }
          return const Center(child: Text('Something went wrong'));
        },
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            HomeUtils.buildFloatingButton(
              label: "Community",
              onTap: () => HomeUtils.navigateToCommunityScreen(context),
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

  // --- HELPER: SECTION HEADER ---
  Widget _buildSectionHeader(String title, Color? textColor, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.blueAccent, size: 20),
            const SizedBox(width: 8),
          ],
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  // --- HELPER: DESKTOP GRID ---
  Widget _buildDesktopGrid(List<LessonModel> lessons, bool isDark) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 350,
        mainAxisExtent: 260,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
      ),
      itemCount: lessons.length,
      itemBuilder: (context, index) {
        final lesson = lessons[index];
        bool isVideo = lesson.type == 'video' || (lesson.videoUrl?.isNotEmpty ?? false);
        
        if (isVideo) {
          return LibraryVideoCard(lesson: lesson, isDark: isDark);
        } else {
          return LibraryTextCard(lesson: lesson, isDark: isDark);
        }
      },
    );
  }

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
            _buildSectionHeader("Playlists", textColor, icon: Icons.playlist_play_rounded),
            
            // Note: Playlists usually look better as a horizontal strip even on desktop
            // to differentiate them from the lesson grids below.
            SizedBox(
              height: 120,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: docs.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final name = data['name'] ?? 'Untitled';
                  final id = docs[index].id;
                  final lessonIds = data['lessonIds'] as List<dynamic>? ?? [];

                  void handleEdit() { _showEditPlaylistDialog(context, userId, id, name); }
                  void handleDelete() { _showDeletePlaylistDialog(context, userId, id); }

                  return Center(
                    child: SizedBox(
                      width: 280,
                      child: Stack(
                        children: [
                          GestureDetector(
                            onLongPress: () {
                              _showPlaylistOptions(context, handleEdit, handleDelete);
                            },
                            child: PlaylistOpenButton(
                              playlistName: name,
                              playlistId: id,
                              lessonIds: lessonIds,
                              currentUserId: userId,
                              isDark: isDark,
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Material(
                              color: Colors.transparent,
                              child: PopupMenuButton<String>(
                                icon: Icon(Icons.more_vert_rounded, color: isDark ? Colors.white70 : Colors.black54, size: 20),
                                onSelected: (val) => val == 'edit' ? handleEdit() : handleDelete(),
                                itemBuilder: (ctx) => [
                                  const PopupMenuItem(value: 'edit', child: Text('Rename')),
                                  const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
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

  void _showPlaylistOptions(BuildContext context, VoidCallback onEdit, VoidCallback onDelete) {
      showModalBottomSheet(
        context: context,
        builder: (ctx) => SafeArea(
          child: Wrap(
            children: [
              ListTile(leading: const Icon(Icons.edit), title: const Text('Rename'), onTap: () { Navigator.pop(ctx); onEdit(); }),
              ListTile(leading: const Icon(Icons.delete, color: Colors.red), title: const Text('Delete'), onTap: () { Navigator.pop(ctx); onDelete(); }),
            ],
          ),
        ),
      );
  }

  void _showEditPlaylistDialog(BuildContext context, String userId, String playlistId, String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Rename Playlist"),
        content: TextField(controller: controller, autofocus: true, textCapitalization: TextCapitalization.sentences),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                 await FirebaseFirestore.instance.collection('users').doc(userId).collection('playlists').doc(playlistId).update({'name': controller.text.trim()});
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _showDeletePlaylistDialog(BuildContext context, String userId, String playlistId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Playlist?"),
        content: const Text("Lessons will not be deleted."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('users').doc(userId).collection('playlists').doc(playlistId).delete();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStateCheck(String userId, String currentLanguage) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(userId).collection('playlists').where('language', isEqualTo: currentLanguage).limit(1).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 100),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.auto_stories, size: 80, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text('Library is empty', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
              ],
            ),
          ),
        );
      },
    );
  }
}