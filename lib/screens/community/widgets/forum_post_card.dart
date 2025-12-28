import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:linguaflow/models/community_models.dart';
import 'package:linguaflow/models/user_model.dart';
import 'package:linguaflow/services/community_service.dart';
import 'package:linguaflow/screens/community/post_details_screen.dart';
import 'community_utils.dart'; 

class ForumPostCard extends StatefulWidget {
  final ForumPost post;
  final UserModel currentUser;
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
    bool liked = await widget.service.hasUserLiked(
      'forum_posts', 
      widget.post.id, 
      widget.currentUser.id
    );
    if(mounted) {
      setState(() => _isLiked = liked);
    }
  }

  void _handleLike() {
    setState(() {
      _isLiked = !_isLiked;
      _currentLikes += _isLiked ? 1 : -1;
    });
    widget.service.toggleLike('forum_posts', widget.post.id, widget.currentUser.id);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // ... (Your existing UI structure mostly same, just updating the Like Button) ...

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PostDetailsScreen(
            post: widget.post,
            currentUser: widget.currentUser,
            service: widget.service,
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundImage: widget.post.authorPhoto != null
                      ? NetworkImage(widget.post.authorPhoto!)
                      : null,
                  child: widget.post.authorPhoto == null
                      ? Text(widget.post.authorName[0])
                      : null,
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.post.authorName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      timeago.format(widget.post.createdAt),
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
                const Spacer(),
                // Menu Logic...
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.grey),
                  onSelected: (val) {
                     // ... Handle report/delete
                  },
                  itemBuilder: (context) => [
                     const PopupMenuItem(value: 'report', child: Text('Report')),
                     // Add delete if owner
                  ],
                )
              ],
            ),
            
            const SizedBox(height: 12),
            Text(widget.post.content, maxLines: 4, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, color: isDark ? Colors.white : Colors.black87)),

            const SizedBox(height: 12),
            const Divider(),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // LIKE BUTTON
                TextButton.icon(
                  onPressed: _handleLike,
                  icon: Icon(
                    _isLiked ? Icons.thumb_up_alt : Icons.thumb_up_alt_outlined, 
                    size: 18,
                    color: _isLiked ? Colors.blue : Colors.grey,
                  ),
                  label: Text("$_currentLikes", style: TextStyle(color: _isLiked ? Colors.blue : Colors.grey)),
                ),
                
                // COMMENT BUTTON
                TextButton.icon(
                  onPressed: () {
                     // Navigate
                  },
                  icon: const Icon(Icons.comment_outlined, size: 18, color: Colors.grey),
                  label: Text("${widget.post.commentCount}", style: const TextStyle(color: Colors.grey)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}