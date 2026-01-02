import 'package:flutter/material.dart';
import 'package:linguaflow/models/community_models.dart';
import 'package:linguaflow/models/user_model.dart';
import 'package:linguaflow/services/community_service.dart';
import 'package:linguaflow/utils/auth_guard.dart'; // Import AuthGuard
import 'package:timeago/timeago.dart' as timeago;

class PostDetailsScreen extends StatefulWidget {
  final ForumPost post;
  final UserModel? currentUser; // Changed to Nullable
  final CommunityService service;

  const PostDetailsScreen({
    super.key,
    required this.post,
    required this.currentUser,
    required this.service,
  });

  @override
  State<PostDetailsScreen> createState() => _PostDetailsScreenState();
}

class _PostDetailsScreenState extends State<PostDetailsScreen> {
  final TextEditingController _commentController = TextEditingController();
  bool _isSending = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final isGuest = widget.currentUser == null;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text("Discussion"),
        backgroundColor: bgColor,
        elevation: 0,
      ),
      body: Column(
        children: [
          // --- SCROLLABLE CONTENT ---
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 1. The Original Post
                _buildOriginalPost(isDark),
                const Divider(height: 32),
                
                const Text(
                  "Comments",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 16),

                // 2. Comments List (StreamBuilder)
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: widget.service.getComments(widget.post.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Center(child: Text("No comments yet. Be the first!")),
                      );
                    }

                    final comments = snapshot.data!;
                    return ListView.separated(
                      shrinkWrap: true, // Vital for nesting inside ListView
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: comments.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        return _buildCommentItem(comments[index], isDark);
                      },
                    );
                  },
                ),
                const SizedBox(height: 80), // Space for input field
              ],
            ),
          ),

          // --- INPUT AREA ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      // GUEST LOGIC: Make read-only so keyboard doesn't open, 
                      // but trigger login on tap.
                      readOnly: isGuest,
                      onTap: isGuest ? () {
                        AuthGuard.run(context, onAuthenticated: () {});
                      } : null,
                      decoration: InputDecoration(
                        hintText: isGuest ? "Log in to comment..." : "Write a comment...",
                        border: InputBorder.none,
                        isDense: true,
                        hintStyle: TextStyle(
                          color: isGuest ? Colors.blueAccent : Colors.grey
                        )
                      ),
                      maxLines: null,
                    ),
                  ),
                  IconButton(
                    icon: _isSending 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                      : Icon(Icons.send, color: isGuest ? Colors.grey : Colors.blue),
                    onPressed: _isSending 
                      ? null 
                      : () {
                          if (isGuest) {
                             AuthGuard.run(context, onAuthenticated: () {});
                          } else {
                            _handlePostComment();
                          }
                        },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePostComment() async {
    // Safety check (though UI prevents it)
    if (widget.currentUser == null) return;

    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);
    try {
      // currentUser is guaranteed not null here because of check above
      await widget.service.addComment(widget.post.id, text, widget.currentUser!);
      _commentController.clear();
      if(mounted) FocusManager.instance.primaryFocus?.unfocus();
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if(mounted) setState(() => _isSending = false);
    }
  }

  Widget _buildCommentItem(Map<String, dynamic> data, bool isDark) {
    // Safely parse date
    DateTime date = DateTime.now();
    if (data['createdAt'] != null) {
      // Firestore Timestamp to Date
      date = (data['createdAt'] as dynamic).toDate();
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundImage: data['authorPhoto'] != null ? NetworkImage(data['authorPhoto']) : null,
          child: data['authorPhoto'] == null 
            ? Text((data['authorName'] ?? "U").toString().substring(0, 1).toUpperCase()) 
            : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      data['authorName'] ?? "User",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    Text(
                      timeago.format(date),
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  data['content'] ?? "",
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOriginalPost(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundImage: widget.post.authorPhoto != null
                  ? NetworkImage(widget.post.authorPhoto!)
                  : null,
              child: widget.post.authorPhoto == null
                  ? Text(widget.post.authorName.isNotEmpty ? widget.post.authorName[0].toUpperCase() : "U")
                  : null,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.post.authorName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  timeago.format(widget.post.createdAt),
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          widget.post.content,
          style: TextStyle(
            fontSize: 16,
            color: isDark ? Colors.white : Colors.black87,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}