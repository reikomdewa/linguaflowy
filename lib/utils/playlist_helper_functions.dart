// -----------------------------------------------------------------------------
// HELPER FUNCTIONS FOR PLAYLISTS (FIXED FOR LANGUAGE FILTERING)
// -----------------------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/services/lesson_cache_service.dart';

// Place this inside your User App code
// import 'package:device_info_plus/device_info_plus.dart'; // Optional
// import 'package:package_info_plus/package_info_plus.dart'; // Optional

void showPlaylistSelector(
  BuildContext context,
  String userId,
  LessonModel lesson,
  bool isDark,
) {
  showDialog(
    context: context,
    builder: (context) {
      // Logic to create a new playlist
      final TextEditingController newPlaylistController =
          TextEditingController();

      return AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text(
          "Select Playlist",
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Input to Create New
              TextField(
                controller: newPlaylistController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  hintText: "Create new playlist...",
                  hintStyle: const TextStyle(color: Colors.grey),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.blue),
                    onPressed: () async {
                      if (newPlaylistController.text.trim().isNotEmpty) {
                        await _createNewPlaylistAndAddLesson(
                          context,
                          userId,
                          newPlaylistController.text.trim(),
                          lesson,
                        );
                        if (context.mounted) Navigator.pop(context);
                      }
                    },
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey[700]!),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 2. List of Existing Playlists (FILTERED BY LANGUAGE)
              Flexible(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(userId)
                      .collection('playlists')
                      // FIX: Only show playlists matching the lesson's language
                      .where('language', isEqualTo: lesson.language)
                      .orderBy('updatedAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Text("Error loading playlists");
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = snapshot.data?.docs ?? [];

                    if (docs.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text(
                          "No playlists for this language yet.",
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        final String playlistName = data['name'] ?? 'Untitled';
                        final String playlistId = docs[index].id;
                        final List<dynamic> lessonIds = data['lessonIds'] ?? [];
                        final bool alreadyAdded = lessonIds.contains(lesson.id);

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.playlist_play,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                          title: Text(
                            playlistName,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          subtitle: Text(
                            "${lessonIds.length} lessons",
                            style: const TextStyle(color: Colors.grey),
                          ),
                          trailing: alreadyAdded
                              ? const Icon(Icons.check, color: Colors.green)
                              : null,
                          onTap: () async {
                            if (!alreadyAdded) {
                              await _addToExistingPlaylist(
                                context,
                                userId,
                                playlistId,
                                lesson,
                              );
                              if (context.mounted) Navigator.pop(context);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Already in this playlist"),
                                ),
                              );
                            }
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      );
    },
  );
}

Future<void> _createNewPlaylistAndAddLesson(
  BuildContext context,
  String userId,
  String name,
  LessonModel lesson,
) async {
  try {
    // 1. CACHE LOCALLY FIRST
    await LessonCacheService().cacheLesson(lesson);

    // 2. Perform Firestore Operations
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('playlists')
        .doc();

    await ref.set({
      'id': ref.id,
      'name': name,
      'language': lesson.language, // FIX: Save language!
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lessonIds': [lesson.id],
      'thumbnailUrl': lesson.imageUrl ?? '',
    });

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Created playlist '$name'")));
    }
  } catch (e) {
    debugPrint("Error creating playlist: $e");
  }
}

// Logic: Add to Existing Playlist
Future<void> _addToExistingPlaylist(
  BuildContext context,
  String userId,
  String playlistId,
  LessonModel lesson,
) async {
  try {
    // 1. CACHE LOCALLY FIRST
    await LessonCacheService().cacheLesson(lesson);

    // 2. Perform Firestore Operations
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('playlists')
        .doc(playlistId);

    await ref.update({
      'lessonIds': FieldValue.arrayUnion([lesson.id]),
      'updatedAt': FieldValue.serverTimestamp(),
      // Optional: Update thumbnail if playlist was empty
      // 'thumbnailUrl': lesson.imageUrl ?? '',
    });

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Added to playlist")));
    }
  } catch (e) {
    debugPrint("Error adding to playlist: $e");
  }
}
