import 'package:flutter/material.dart';
import 'package:linguaflow/screens/community/widgets/community_utils.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/models/user_model.dart';
import 'package:linguaflow/services/community_service.dart';
import 'package:linguaflow/screens/reader/reader_screen.dart';

class CommunityLessonCard extends StatefulWidget {
  final LessonModel lesson;
  final UserModel currentUser;
  final CommunityService service;

  const CommunityLessonCard({
    super.key,
    required this.lesson,
    required this.currentUser,
    required this.service,
  });

  @override
  State<CommunityLessonCard> createState() => _CommunityLessonCardState();
}

class _CommunityLessonCardState extends State<CommunityLessonCard> {
  bool _isLiked = false;
  int _currentLikes = 0;
  // REMOVED: bool _isLoadingLike = true; <--- We don't want to block the UI

  @override
  void initState() {
    super.initState();
    _currentLikes = widget.lesson.likes;
    _checkIfLiked();
  }

  void _checkIfLiked() async {
    // This runs in background. The UI shows the heart immediately.
    bool liked = await widget.service.hasUserLiked(
      'lessons',
      widget.lesson.id,
      widget.currentUser.id,
    );

    // Only update if the widget is still on screen
    if (mounted) {
      setState(() {
        _isLiked = liked;
      });
    }
  }

  void _handleLike() {
    setState(() {
      _isLiked = !_isLiked;
      _currentLikes += _isLiked ? 1 : -1;
    });

    widget.service.toggleLike(
      'lessons',
      widget.lesson.id,
      widget.currentUser.id,
    );
  }

  // ... (Keep _getYoutubeThumbnail helper unchanged) ...
  String? _getYoutubeThumbnail(String url) {
    if (url.isEmpty) return null;
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    String? videoId;
    if (uri.host.contains('youtube.com')) {
      videoId = uri.queryParameters['v'];
    } else if (uri.host.contains('youtu.be')) {
      videoId = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
    }
    if (videoId != null) {
      return 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bool isVideo =
        widget.lesson.type == 'video' ||
        (widget.lesson.videoUrl != null && widget.lesson.videoUrl!.isNotEmpty);

    String? thumbnailUrl;
    if (isVideo && widget.lesson.videoUrl != null) {
      thumbnailUrl = _getYoutubeThumbnail(widget.lesson.videoUrl!);
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER (Unchanged)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            leading: CircleAvatar(
              backgroundColor: Colors.grey[300],
              child: const Icon(Icons.person, color: Colors.grey),
            ),
            title: Text(
              widget.lesson.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text("Shared ${timeago.format(widget.lesson.createdAt)}"),
          ),

          // BODY (Unchanged)
          GestureDetector(
            onTap: () {
              widget.service.incrementLessonViews(widget.lesson.id);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ReaderScreen(lesson: widget.lesson),
                ),
              );
            },
            child: Container(
              height: 140,
              width: double.infinity,
              color: isVideo
                  ? Colors.black
                  : Colors.grey.withValues(alpha: 0.1),
              alignment: Alignment.center,
              child: isVideo
                  ? Stack(
                      alignment: Alignment.center,
                      fit: StackFit.expand,
                      children: [
                        if (thumbnailUrl != null)
                          Image.network(
                            thumbnailUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const SizedBox.shrink(),
                          ),
                        if (thumbnailUrl != null)
                          Container(color: Colors.black.withValues(alpha: 0.3)),
                        const Center(
                          child: Icon(
                            Icons.play_circle_fill,
                            size: 48,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    )
                  : Padding(
                      padding: const EdgeInsets.all(16),
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Text(
                          widget.lesson.content,
                          maxLines: 5,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isDark ? Colors.grey[300] : Colors.grey[700],
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
            ),
          ),

          // --- FOOTER (FIXED) ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                // LIKE BUTTON (No Spinner)
                InkWell(
                  onTap: _handleLike,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        // Directly show the Icon. It defaults to border (grey)
                        // until _checkIfLiked completes or user taps it.
                        Icon(
                          _isLiked ? Icons.favorite : Icons.favorite_border,
                          size: 20,
                          color: _isLiked ? Colors.pink : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "$_currentLikes",
                          style: TextStyle(
                            color: _isLiked ? Colors.pink : Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // VIEWS
                StatBadge(
                  icon: Icons.remove_red_eye,
                  count: widget.lesson.views,
                  color: Colors.blue,
                ),

                const Spacer(),

                // MENU
                PopupMenuButton(
                  icon: Icon(
                    Icons.more_vert,
                    color: isDark ? Colors.white70 : Colors.grey[700],
                  ),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'save',
                      child: Row(
                        children: [
                          Icon(Icons.bookmark_add, color: Colors.blue),
                          SizedBox(width: 12),
                          Text("Save to Library"),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'report',
                      child: Row(
                        children: [
                          Icon(Icons.flag_outlined, color: Colors.grey),
                          SizedBox(width: 12),
                          Text("Report Content"),
                        ],
                      ),
                    ),
                    if (widget.lesson.userId == widget.currentUser.id)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, color: Colors.red),
                            SizedBox(width: 12),
                            Text("Delete", style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                  ],
                  onSelected: (val) async {
                    if (val == 'save') {
                      await widget.service.saveLessonToLibrary(
                        widget.lesson,
                        widget.currentUser.id,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Saved to your Library!"),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } else if (val == 'report') {
                      showReportDialog(
                        context,
                        widget.lesson.id,
                        'lesson',
                        widget.service,
                        widget.currentUser,
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
