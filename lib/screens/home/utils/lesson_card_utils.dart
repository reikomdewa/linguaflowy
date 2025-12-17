/// Filters the list so that only ONE video from a specific series/playlist appears.
/// Takes the first occurrence (which is usually the newest if sorted by date).
/// import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/lesson/lesson_bloc.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/constants/constants.dart';
import 'package:linguaflow/screens/reader/reader_screen.dart';
import 'package:linguaflow/services/repositories/lesson_repository.dart';
import 'package:linguaflow/utils/playlist_helper_functions.dart';
import 'package:package_info_plus/package_info_plus.dart';

void showPlaylistBottomSheet(
  BuildContext parentContext,
  LessonModel currentLesson,
  List<LessonModel> allLessons,
  bool isDark,
) {
  if (currentLesson.seriesId == null) return;

  final String seriesId = currentLesson.seriesId!;

  // 1. FILTER & SORT (Order: Part 1 -> Part 10)
  final List<LessonModel> playlist = allLessons
      .where((l) => l.seriesId == seriesId)
      .toList();

  playlist.sort((a, b) => (a.seriesIndex ?? 0).compareTo(b.seriesIndex ?? 0));

  // 2. THE CHEAT: FORCE START AT PART 1
  // We try to find the current lesson.
  int selectedPlaylistIndex = playlist.indexWhere(
    (l) => (l.id?.toString().trim() == currentLesson.id?.toString().trim()),
  );

  // BUG FIX: If it selected the LAST item (likely your parsing bug) or nothing (-1),
  // we force the selection to 0 (The first video).
  if (selectedPlaylistIndex == -1 ||
      selectedPlaylistIndex == playlist.length - 1) {
    selectedPlaylistIndex = 0;
  }

  showModalBottomSheet(
    context: parentContext,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) {
      return DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (scrollContext, scrollController) {
          // Auto-scroll only if we are deep in the list (e.g. Part 50)
          // Since we default to 0, this usually won't run, keeping the top visible.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (scrollController.hasClients && selectedPlaylistIndex > 3) {
              scrollController.jumpTo(selectedPlaylistIndex * 72.0);
            }
          });

          return Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: ListView.builder(
              controller: scrollController,
              itemCount: 1 + playlist.length,
              itemBuilder: (itemContext, index) {
                // --- HEADER ---
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Text(
                          currentLesson.seriesTitle ?? "Playlist",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        Text(
                          "${playlist.length} Videos",
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        const Divider(height: 1),
                      ],
                    ),
                  );
                }

                // --- ITEM ---
                final itemIndex = index - 1;
                final item = playlist[itemIndex];

                // Uses our "Cheated" Index (0)
                final isCurrent = (itemIndex == selectedPlaylistIndex);

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  selected: isCurrent,
                  selectedTileColor: isDark
                      ? Colors.blue.withOpacity(0.1)
                      : Colors.blue.withOpacity(0.05),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 80,
                      height: 45,
                      child:
                          (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                          ? Image.network(
                              item.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  Container(color: Colors.grey[800]),
                            )
                          : Container(color: Colors.grey[800]),
                    ),
                  ),
                  title: Text(
                    "Part ${item.seriesIndex ?? (itemIndex + 1)}: ${item.title}",
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isCurrent
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isCurrent
                          ? Colors.blue
                          : (isDark ? Colors.white70 : Colors.black87),
                    ),
                  ),
                  trailing: isCurrent
                      ? const Icon(
                          Icons.play_circle_filled,
                          color: Colors.blue,
                          size: 24,
                        )
                      : const Icon(
                          Icons.play_arrow_outlined,
                          size: 20,
                          color: Colors.grey,
                        ),
                  onTap: () async {
                    Navigator.pop(itemContext); // Close Sheet

                    // REMOVE: if (!isCurrent)
                    // We want to navigate regardless of whether it's highlighted in the list

                    await Navigator.push(
                      parentContext,
                      MaterialPageRoute(
                        builder: (context) => ReaderScreen(lesson: item),
                      ),
                    );

                    // When returning from the ReaderScreen, re-show the bottom sheet
                    // with the newly "active" lesson.
                    if (parentContext.mounted) {
                      showPlaylistBottomSheet(
                        parentContext,
                        item, // The lesson that was just played
                        allLessons,
                        isDark,
                      );
                    }
                  },
                );
              },
            ),
          );
        },
      );
    },
  );
}

List<LessonModel> deduplicateSeries(List<LessonModel> input) {
  final Set<String> seenSeriesIds = {};
  final List<LessonModel> filtered = [];

  for (var lesson in input) {
    if (lesson.seriesId == null || lesson.seriesId!.isEmpty) {
      // Not a playlist video, always show
      filtered.add(lesson);
    } else {
      // It is a playlist video
      if (!seenSeriesIds.contains(lesson.seriesId)) {
        seenSeriesIds.add(lesson.seriesId!);
        filtered.add(lesson);
      }
      // Else: We've already shown a card for this series, skip this one
    }
  }
  return filtered;
}

void showLessonOptions(
  BuildContext context,
  LessonModel lesson,
  bool isDark, {
  bool showDeleteAction = false,
}) {
  final parentContext = context;
  final authState = parentContext.read<AuthBloc>().state;
  String currentUserId = '';
  bool canDelete = false;
  bool isOwner = false;
  bool isCreatedByMe = false;

  if (authState is AuthAuthenticated) {
    final user = authState.user;
    currentUserId = user.id;
    isOwner = (user.id == lesson.userId);
    isCreatedByMe =
        isOwner &&
        (lesson.originalAuthorId == null ||
            lesson.originalAuthorId == lesson.userId);
    final bool isAdmin = AppConstants.isAdmin(user.email);
    canDelete = isAdmin || isCreatedByMe || (isOwner && showDeleteAction);
  }

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (builderContext) => Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
          // Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // --- FAVORITE / SAVE BUTTON ---
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: lesson.isFavorite
                    ? Colors.amber.withValues(alpha: 0.1)
                    : (isDark ? Colors.white10 : Colors.grey[100]),
                shape: BoxShape.circle,
              ),
              child: Icon(
                lesson.isFavorite ? Icons.star : Icons.star_border,
                color: lesson.isFavorite ? Colors.amber : Colors.grey,
              ),
            ),
            title: Text(
              lesson.isFavorite ? 'Remove from Favorites' : 'Save to Library',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            subtitle: Text(
              isOwner
                  ? (lesson.isFavorite
                        ? 'Unfavorite (removes from library)'
                        : 'Add to favorites')
                  : 'Create a copy in your cloud library.',
              style: const TextStyle(color: Colors.grey),
            ),
            onTap: () {
              if (currentUserId.isEmpty) {
                Navigator.pop(builderContext);
                return;
              }
              if (isOwner) {
                final updatedLesson = lesson.copyWith(
                  isFavorite: !lesson.isFavorite,
                );
                parentContext.read<LessonBloc>().add(
                  LessonUpdateRequested(updatedLesson),
                );
              } else {
                final newLesson = lesson.copyWith(
                  id: '',
                  userId: currentUserId,
                  originalAuthorId: lesson.userId,
                  isFavorite: true,
                  isLocal: false,
                  createdAt: DateTime.now(),
                );
                parentContext.read<LessonBloc>().add(
                  LessonCreateRequested(newLesson),
                );
                ScaffoldMessenger.of(parentContext).showSnackBar(
                  const SnackBar(content: Text("Saved to Favorites & Library")),
                );
              }
              Navigator.pop(builderContext);
            },
          ),

          Divider(color: Colors.grey[800], indent: 20, endIndent: 20),

          // --- NEW: ADD TO PLAYLIST BUTTON ---
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.playlist_add, color: Colors.blueAccent),
            ),
            title: Text(
              'Add to Playlist',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            subtitle: const Text(
              'Add to an existing playlist or create new',
              style: TextStyle(color: Colors.grey),
            ),
            onTap: () {
              // Close the bottom sheet first
              Navigator.pop(builderContext);

              if (currentUserId.isNotEmpty) {
                // Open the Playlist Selection Dialog
                showPlaylistSelector(context, currentUserId, lesson, isDark);
              }
            },
          ),

          // --- DELETE BUTTON ---
          if (canDelete) ...[
            Divider(color: Colors.grey[800], indent: 20, endIndent: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_outline, color: Colors.red),
              ),
              title: const Text(
                'Delete Lesson',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text("Delete Lesson?"),
                    content: Text(
                      isCreatedByMe
                          ? "This is your created lesson. Deleting it will remove it permanently for everyone."
                          : "This will remove the lesson from your library.",
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text("Cancel"),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          parentContext.read<LessonBloc>().add(
                            LessonDeleteRequested(lesson.id),
                          );
                          Navigator.pop(builderContext);
                          ScaffoldMessenger.of(parentContext).showSnackBar(
                            const SnackBar(
                              content: Text("Lesson Deleted"),
                              backgroundColor: Colors.red,
                            ),
                          );
                        },
                        child: const Text(
                          "Delete",
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    ),
  );
}

void showReportBugDialog(
  BuildContext context,
  String userId,
  String userEmail,
) {
  final titleCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  String severity = 'medium';

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text("Report a Problem"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: "Subject",
                  hintText: "e.g., Audio not playing",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: descCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: "Description",
                  hintText: "Explain what happened step by step...",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                initialValue: severity,
                decoration: const InputDecoration(labelText: "Impact"),
                items: ['low', 'medium', 'high', 'critical']
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(s.toUpperCase()),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => severity = v!),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleCtrl.text.isEmpty) return;

              String deviceInfo = "Unknown Device";
              String appVersion = "1.0.0";

              try {
                final info = await DeviceInfoPlugin().deviceInfo;
                if (info is AndroidDeviceInfo)
                  deviceInfo =
                      "${info.brand} ${info.model} (SDK ${info.version.sdkInt})";
                if (info is IosDeviceInfo)
                  deviceInfo = "${info.name} (${info.systemVersion})";
                final pkg = await PackageInfo.fromPlatform();
                appVersion = "${pkg.version} (${pkg.buildNumber})";
              } catch (_) {}

              // 2. Write to Firestore
              await FirebaseFirestore.instance.collection('bug_reports').add({
                'title': titleCtrl.text,
                'description': descCtrl.text,
                'severity': severity,
                'status': 'open',
                'userId': userId,
                'userEmail': userEmail,
                'deviceInfo': deviceInfo,
                'appVersion': appVersion,
                'createdAt': FieldValue.serverTimestamp(),
              });

              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Report sent! Thank you.")),
                );
              }
            },
            child: const Text("Submit Report"),
          ),
        ],
      ),
    ),
  );
}
