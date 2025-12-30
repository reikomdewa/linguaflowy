import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:timeago/timeago.dart' as timeago;

// BLOCS
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_state.dart';
import 'package:linguaflow/blocs/auth/auth_event.dart';

// MODELS & SERVICES
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/models/user_model.dart';
import 'package:linguaflow/services/community_service.dart';
import 'package:linguaflow/screens/reader/reader_screen.dart';
import 'package:linguaflow/screens/community/widgets/community_utils.dart'; // Assuming StatBadge is here

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

  @override
  void initState() {
    super.initState();
    _currentLikes = widget.lesson.likes;
    _checkIfLiked();
  }

  void _checkIfLiked() async {
    bool liked = await widget.service.hasUserLiked(
      'lessons',
      widget.lesson.id,
      widget.currentUser.id,
    );
    if (mounted) {
      setState(() => _isLiked = liked);
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 1. WATCH AUTH STATE
    // This ensures the menu updates immediately (Follow -> Unfollow) without needing a page refresh
    final authState = context.watch<AuthBloc>().state;
    final user = authState.user;
    bool isFollowing = false;
    bool isMe = widget.lesson.userId == widget.currentUser.id;

    if (authState is AuthAuthenticated) {
      isFollowing = authState.user.following.contains(widget.lesson.userId);
    }

    // 2. Video Logic
    final bool isVideo =
        widget.lesson.type == 'video' ||
        (widget.lesson.videoUrl != null && widget.lesson.videoUrl!.isNotEmpty);

    String? thumbnailUrl;
    if (isVideo && widget.lesson.videoUrl != null) {
      thumbnailUrl = _getYoutubeThumbnail(widget.lesson.videoUrl!);
    }
    final bool isAiGenerated = widget.lesson.originality == 'ai_story';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
          // --- HEADER (Clean, no button here) ---
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            leading: CircleAvatar(
              radius: 20,
              backgroundColor: Colors.grey[300],
              child: const Icon(Icons.person, color: Colors.grey),
            ),
            title: Text(
              widget.lesson.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              "Shared ${timeago.format(widget.lesson.createdAt)} by ${user?.displayName} ",
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),

          // --- BODY ---
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
              color: isVideo ? Colors.black : Colors.grey.withOpacity(0.1),
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
                            errorBuilder: (_, __, ___) =>
                                const SizedBox.shrink(),
                          ),
                        if (thumbnailUrl != null)
                          Container(color: Colors.black.withOpacity(0.3)),
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

          // --- FOOTER ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // LIKE
                InkWell(
                  onTap: _handleLike,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
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
                isAiGenerated
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.purple.withOpacity(0.3),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              size: 12,
                              color: Colors.purple,
                            ),
                            SizedBox(width: 4),
                            Text(
                              "AI graded",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.purple,
                              ),
                            ),
                          ],
                        ),
                      )
                    : SizedBox.shrink(),
                // --- MENU WITH FOLLOW LOGIC ---
                PopupMenuButton(
                  icon: Icon(
                    Icons.more_vert,
                    color: isDark ? Colors.white70 : Colors.grey[700],
                  ),
                  itemBuilder: (context) => [
                    // 1. Follow / Unfollow (Only if not me)
                    if (!isMe)
                      PopupMenuItem(
                        value: 'toggle_follow',
                        child: Row(
                          children: [
                            Icon(
                              isFollowing
                                  ? Icons.person_remove
                                  : Icons.person_add,
                              color: theme.primaryColor,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              isFollowing ? "Unfollow Author" : "Follow Author",
                            ),
                          ],
                        ),
                      ),

                    // 2. Save
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

                    // 3. Report
                    const PopupMenuItem(
                      value: 'report',
                      child: Row(
                        children: [
                          Icon(Icons.flag_outlined, color: Colors.grey),
                          SizedBox(width: 12),
                          Text("Report"),
                        ],
                      ),
                    ),

                    // 4. Delete (Only if me)
                    if (isMe)
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
                    if (val == 'toggle_follow') {
                      if (isFollowing) {
                        context.read<AuthBloc>().add(
                          AuthUnfollowUser(widget.lesson.userId),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Unfollowed author")),
                        );
                      } else {
                        context.read<AuthBloc>().add(
                          AuthFollowUser(widget.lesson.userId),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Followed author!")),
                        );
                      }
                    } else if (val == 'save') {
                      await widget.service.saveLessonToLibrary(
                        widget.lesson,
                        widget.currentUser.id,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Saved to Library!"),
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
