import 'package:flutter/material.dart';
import 'package:linguaflow/widgets/user_follow_button.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:linguaflow/models/community_models.dart';
import 'package:linguaflow/models/user_model.dart';
import 'package:linguaflow/services/community_service.dart';
import 'package:linguaflow/screens/community/post_details_screen.dart';
import 'package:linguaflow/utils/auth_guard.dart'; // Import AuthGuard

class ForumPostCard extends StatefulWidget {
  final ForumPost post;
  final UserModel? currentUser; // Nullable for Guests
  final CommunityService service;

  const ForumPostCard({
    super.key,
    required this.post,
    required this.currentUser,
    required this.service,
  });

  @override
  State<ForumPostCard> createState() => _ForumPostCardState();
}

class _ForumPostCardState extends State<ForumPostCard> {
  bool _isLiked = false;
  int _currentLikes = 0;

  @override
  void initState() {
    super.initState();
    _currentLikes = widget.post.likes;
    _checkIfLiked();
  }

  void _checkIfLiked() async {
    // If guest, they haven't liked it
    if (widget.currentUser == null) return;

    bool liked = await widget.service.hasUserLiked(
      'forum_posts',
      widget.post.id,
      widget.currentUser!.id,
    );
    if (mounted) {
      setState(() => _isLiked = liked);
    }
  }

  void _handleLike() {
    AuthGuard.run(context, onAuthenticated: () {
      if (widget.currentUser == null) return;

      setState(() {
        _isLiked = !_isLiked;
        _currentLikes += _isLiked ? 1 : -1;
      });
      widget.service.toggleLike(
        'forum_posts',
        widget.post.id,
        widget.currentUser!.id,
      );
    });
  }

  void _navigateToDetails() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailsScreen(
          post: widget.post,
          currentUser: widget.currentUser, // Pass nullable user
          service: widget.service,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Helper: Check if I am the author (safely)
    final bool isMyPost = widget.currentUser != null && 
                          widget.post.authorId == widget.currentUser!.id;

    return GestureDetector(
      onTap: _navigateToDetails,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.grey[200]!,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER ---
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundImage: widget.post.authorPhoto != null
                      ? NetworkImage(widget.post.authorPhoto!)
                      : null,
                  child: widget.post.authorPhoto == null
                      ? Text(widget.post.authorName.isNotEmpty 
                          ? widget.post.authorName[0].toUpperCase() 
                          : "U")
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.post.authorName.isNotEmpty ? widget.post.authorName : "Anonymous",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        timeago.format(widget.post.createdAt),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),

                // FOLLOW BUTTON (Hidden for Guests and Myself)
                if (widget.currentUser != null && !isMyPost)
                  UserFollowButton(
                    targetUserId: widget.post.authorId,
                    activeColor: theme.primaryColor,
                  ),

                // MENU
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.grey),
                  onSelected: (val) {
                    if (val == 'delete') {
                      // Implement delete logic here
                    } else if (val == 'report') {
                      AuthGuard.run(context, onAuthenticated: () {
                        // Implement report logic here
                      });
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'report', child: Text('Report')),
                    if (isMyPost)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          'Delete',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // --- CONTENT ---
            Text(
              widget.post.content,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                height: 1.4,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),

            const SizedBox(height: 12),
            const Divider(),

            // --- ACTIONS ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // LIKE BUTTON
                TextButton.icon(
                  onPressed: _handleLike,
                  icon: Icon(
                    _isLiked ? Icons.thumb_up_alt : Icons.thumb_up_alt_outlined,
                    size: 20,
                    color: _isLiked ? Colors.blue : Colors.grey,
                  ),
                  label: Text(
                    "$_currentLikes",
                    style: TextStyle(
                      color: _isLiked ? Colors.blue : Colors.grey,
                    ),
                  ),
                ),

                // COMMENT BUTTON
                TextButton.icon(
                  onPressed: _navigateToDetails,
                  icon: const Icon(
                    Icons.comment_outlined,
                    size: 20,
                    color: Colors.grey,
                  ),
                  label: Text(
                    "${widget.post.commentCount}",
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}