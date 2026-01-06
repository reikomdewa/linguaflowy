import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_state.dart';
import 'package:linguaflow/models/private_chat_models.dart';
import 'package:linguaflow/services/speak/private_chat_service.dart';

class PrivateChatScreen extends StatefulWidget {
  final String chatId;
  final String otherUserName;
  final String? otherUserPhoto;

  const PrivateChatScreen({
    super.key,
    required this.chatId,
    required this.otherUserName,
    this.otherUserPhoto,
  });

  @override
  State<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final PrivateChatService _service = PrivateChatService();

  // We need to store myId to check message ownership
  String? _myId;

  @override
  void initState() {
    super.initState();
    // 1. Get Current User ID safely
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      _myId = authState.user.id;
      // 2. Mark messages as read (This triggers Blue Ticks for the sender)
      _service.markChatAsRead(widget.chatId, _myId!);
    }
  }

  void _sendMessage() {
    if (_controller.text.trim().isEmpty) return;

    // Get latest user details from Bloc
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    final myUser = authState.user;

    // Fallback for empty name
    final validMyName = myUser.displayName.isEmpty
        ? "User"
        : myUser.displayName;

    _service.sendMessage(
      chatId: widget.chatId,
      senderId: myUser.id,
      text: _controller.text,
      // 3. Pass Metadata
      senderName: validMyName,
      senderPhoto: myUser.photoUrl,
      otherName: widget.otherUserName,
      otherPhoto: widget.otherUserPhoto,
    );

    _controller.clear();
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return "$hour:$minute";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.iconTheme.color),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: theme.dividerColor,
              backgroundImage: widget.otherUserPhoto != null
                  ? CachedNetworkImageProvider(widget.otherUserPhoto!)
                  : null,
              child: widget.otherUserPhoto == null
                  ? Text(
                      widget.otherUserName.isNotEmpty
                          ? widget.otherUserName[0].toUpperCase()
                          : "?",
                      style: TextStyle(color: theme.primaryColor),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.otherUserName,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // --- MESSAGE LIST ---
          Expanded(
            child: StreamBuilder<List<PrivateMessage>>(
              stream: _service.getMessages(widget.chatId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snapshot.data!;
                   // Check if there are any messages NOT sent by me that are unread
                // We use _myId safely here
                if (_myId != null && messages.isNotEmpty) {
                  final hasUnreadMessages = messages.any((msg) => 
                      msg.senderId != _myId && !msg.isRead
                  );

                  if (hasUnreadMessages) {
                    // We must delay the write operation until after the build phase
                    // to avoid "setState() or markNeedsBuild() called during build" errors.
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _service.markChatAsRead(widget.chatId, _myId!);
                    });
                  }
                }

                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      "Start the conversation 👋",
                      style: TextStyle(color: theme.hintColor),
                    ),
                  );
                }

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: messages.length,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    return _buildMessageBubble(msg, theme, isDark);
                  },
                );
              },
            ),
          ),

          // --- INPUT AREA ---
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      style: TextStyle(
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                      decoration: InputDecoration(
                        hintText: "Message...",
                        hintStyle: TextStyle(color: theme.hintColor),
                        filled: true,
                        fillColor: theme.cardColor,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(
                            color: theme.dividerColor,
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Send Button
                  GestureDetector(
                    onTap: _sendMessage,
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor: theme.primaryColor,
                      child: Icon(
                        Icons.arrow_upward_rounded,
                        color: isDark ? Colors.black : Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- BUBBLE BUILDER ---
  Widget _buildMessageBubble(PrivateMessage msg, ThemeData theme, bool isDark) {
    // Check sender using stored ID
    final isMe = msg.senderId == _myId;

    // Theme-Aware Colors
    final myBubbleColor = theme.primaryColor;
    final otherBubbleColor = theme.cardColor;

    final myTextColor = isDark ? Colors.black : Colors.white;
    final otherTextColor = theme.textTheme.bodyLarge?.color;

    // Meta Color (Time)
    final metaColor = isMe
        ? (isDark ? Colors.black54 : Colors.white70)
        : theme.hintColor;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        decoration: BoxDecoration(
          color: isMe ? myBubbleColor : otherBubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Text
            Text(
              msg.text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isMe ? myTextColor : otherTextColor,
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 2),

            // 2. Metadata Row (Time + Ticks)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(msg.createdAt),
                  style: TextStyle(fontSize: 11, color: metaColor),
                ),

                // Show ticks only if I sent the message
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.done_all,
                    size: 16,
                    // FIX: Use bright colors so it's visible in both modes
                    color: msg.isRead
                        ? (isDark ? Colors.lightBlueAccent : Colors.blue)
                        : metaColor,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
