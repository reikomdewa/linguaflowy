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

  void _sendMessage(String myId) {
    if (_controller.text.trim().isEmpty) return;
    _service.sendMessage(widget.chatId, myId, _controller.text);
    _controller.clear();
  }
  @override
  void initState() {
    super.initState();
    // CALL THIS: Clear the badge when screen opens
    PrivateChatService().markChatAsRead(widget.chatId);
  }
  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    String myId = (authState as AuthAuthenticated).user.id;
    
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Determine colors based on your specific Theme definition
    // My Bubble: Primary Color (Black in Light, White in Dark)
    final myBubbleColor = theme.primaryColor;
    final myTextColor = isDark ? Colors.black : Colors.white;

    // Other Bubble: Card Color
    final otherBubbleColor = theme.cardColor;
    final otherTextColor = theme.textTheme.bodyLarge?.color;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: theme.dividerColor,
              backgroundImage: widget.otherUserPhoto != null
                  ? NetworkImage(widget.otherUserPhoto!)
                  : null,
              child: widget.otherUserPhoto == null
                  ? Text(
                      widget.otherUserName[0].toUpperCase(),
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
          // MESSAGE LIST
          Expanded(
            child: StreamBuilder<List<PrivateMessage>>(
              stream: _service.getMessages(widget.chatId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snapshot.data!;

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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: messages.length,
                  // Hides keyboard on scroll for better UX
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderId == myId;

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16, 
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isMe ? myBubbleColor : otherBubbleColor,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(20),
                            topRight: const Radius.circular(20),
                            bottomLeft: isMe ? const Radius.circular(20) : Radius.zero,
                            bottomRight: isMe ? Radius.zero : const Radius.circular(20),
                          ),
                        ),
                        child: Text(
                          msg.text,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isMe ? myTextColor : otherTextColor,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // INPUT AREA (In Safe Area)
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
                        fillColor: theme.cardColor, // Matches Threads input style
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
                    onTap: () => _sendMessage(myId),
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
}