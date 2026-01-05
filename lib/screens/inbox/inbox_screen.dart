import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_state.dart';
import 'package:linguaflow/models/private_chat_models.dart';
import 'package:linguaflow/screens/inbox/private_chat_screen.dart';
import 'package:linguaflow/services/speak/private_chat_service.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  // State to track selected chat on Desktop
  String? _selectedChatId;
  String? _selectedChatName;
  String? _selectedChatPhoto;

  // --- HELPER: Time Formatting (WhatsApp Style) ---
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays == 0 && now.day == timestamp.day) {
      // Today: "14:30"
      final hour = timestamp.hour.toString().padLeft(2, '0');
      final minute = timestamp.minute.toString().padLeft(2, '0');
      return "$hour:$minute";
    } else if (difference.inDays == 0 || (difference.inDays == 1 && now.day != timestamp.day)) {
      // Yesterday
      return "Yesterday";
    } else {
      // Older: "05/01/26"
      return "${timestamp.day}/${timestamp.month}/${timestamp.year.toString().substring(2)}";
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final theme = Theme.of(context);

    // 1. GUEST / NOT LOGGED IN HANDLING
    if (authState is! AuthAuthenticated || authState.isGuest) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_person, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text("Inbox is unavailable for guests"),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/login'),
                child: const Text("Create Account"),
              ),
            ],
          ),
        ),
      );
    }

    final myUser = authState.user;

    return Scaffold(
      // Only show main AppBar on Mobile. On Desktop, the list is just a sidebar.
      appBar: MediaQuery.of(context).size.width < 800
          ? AppBar(title: const Text("Messages"))
          : null,
      // ---------------------------------------------------------
      // SAFE: This StreamBuilder ONLY reads data. It never writes.
      // ---------------------------------------------------------
      body: StreamBuilder<List<PrivateConversation>>(
        stream: PrivateChatService().getInbox(myUser.id),
        builder: (context, snapshot) {
          // 2. LOADING
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // 3. ERROR
          if (snapshot.hasError) {
            debugPrint("❌ Inbox Query Error: ${snapshot.error}");
            return const Center(child: Text("Error loading chats"));
          }

          // 4. EMPTY
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 64, color: theme.hintColor),
                  const SizedBox(height: 16),
                  const Text("No messages yet"),
                ],
              ),
            );
          }

          final chats = snapshot.data!;

          // 5. RESPONSIVE LAYOUT
          return LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 800;

              // The List Widget
              final Widget chatList = ListView.separated(
                padding: isDesktop ? const EdgeInsets.only(top: 10) : EdgeInsets.zero,
                itemCount: chats.length,
                separatorBuilder: (_, __) => const SizedBox.shrink(),
                itemBuilder: (context, index) {
                  final chat = chats[index];
                  
                  // Identify Other User
                  final otherId = chat.participants.firstWhere(
                    (id) => id != myUser.id,
                    orElse: () => chat.participants.first,
                  );
                  final otherData = chat.participantData[otherId] ?? {};
                  final name = otherData['name'] ?? 'User';
                  final photo = otherData['photo'];

                  // ---------------------------------------------------------
                  // LOGIC: VISUAL BADGE HANDLING
                  // ---------------------------------------------------------
                  final bool isLastMsgFromMe = chat.lastSenderId == myUser.id;
                  
                  // If I sent the last message, I don't see a badge (even if DB says 1).
                  // If they sent it, we show the count from the DB.
                  final int unreadCount = isLastMsgFromMe ? 0 : chat.unreadCount;
                  final bool hasUnread = unreadCount > 0;

                  final bool isSelected = _selectedChatId == chat.id;

                  // Format Subtitle
                  String subtitleText = chat.lastMessage;
                  if (isLastMsgFromMe) {
                    subtitleText = "You: $subtitleText";
                  }

                  return ListTile(
                    key: ValueKey(chat.id),
                    selected: isDesktop && isSelected,
                    selectedTileColor: theme.colorScheme.primary.withOpacity(0.1),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    
                    // AVATAR
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundImage: photo != null ? NetworkImage(photo) : null,
                      backgroundColor: theme.dividerColor,
                      child: photo == null
                          ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: TextStyle(fontWeight: FontWeight.bold, color: theme.primaryColor))
                          : null,
                    ),
                    
                    // NAME
                    title: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      maxLines: 1, 
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    // MESSAGE PREVIEW (Bold if unread)
                    subtitle: Text(
                      subtitleText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: hasUnread ? FontWeight.w700 : FontWeight.normal,
                        color: hasUnread ? theme.textTheme.bodyMedium?.color : theme.hintColor,
                        fontSize: 14,
                      ),
                    ),
                    
                    // TIME & BADGE
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // 1. Time (Green if unread)
                        Text(
                          _formatTimestamp(chat.lastMessageTime),
                          style: TextStyle(
                            color: hasUnread ? theme.primaryColor : theme.hintColor,
                            fontSize: 12,
                            fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        
                        const SizedBox(height: 6),
                        
                        // 2. Unread Badge
                        if (hasUnread)
                          Container(
                            width: 22,
                            height: 22,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: theme.primaryColor,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              unreadCount > 99 ? '99+' : '$unreadCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        else 
                          const SizedBox(width: 22, height: 22), 
                      ],
                    ),
                    
                    onTap: () {
                      if (isDesktop) {
                        setState(() {
                          _selectedChatId = chat.id;
                          _selectedChatName = name;
                          _selectedChatPhoto = photo;
                        });
                        // Note: On Desktop, the PrivateChatScreen opens on the right.
                        // PrivateChatScreen WILL mark as read, which will update this stream automatically.
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PrivateChatScreen(
                              chatId: chat.id,
                              otherUserName: name,
                              otherUserPhoto: photo,
                            ),
                          ),
                        );
                      }
                    },
                  );
                },
              );

              if (isDesktop) {
                // --- DESKTOP SPLIT VIEW ---
                return Row(
                  children: [
                    SizedBox(
                      width: 350,
                      child: Column(
                        children: [
                          Container(
                            height: kToolbarHeight,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            color: theme.scaffoldBackgroundColor,
                            child: const Text("Messages", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          ),
                          const Divider(height: 1),
                          Expanded(child: chatList),
                        ],
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: _selectedChatId != null
                          ? PrivateChatScreen(
                              key: ValueKey(_selectedChatId),
                              chatId: _selectedChatId!,
                              otherUserName: _selectedChatName ?? "Chat",
                              otherUserPhoto: _selectedChatPhoto,
                            )
                          : _buildDesktopPlaceholder(theme),
                    ),
                  ],
                );
              } else {
                // --- MOBILE VIEW ---
                return chatList;
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildDesktopPlaceholder(ThemeData theme) {
    return Container(
      color: theme.brightness == Brightness.dark ? Colors.black12 : Colors.grey[50],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.forum_outlined, size: 80, color: theme.disabledColor),
            const SizedBox(height: 20),
            Text("Select a conversation", style: TextStyle(fontSize: 22, color: theme.disabledColor)),
          ],
        ),
      ),
    );
  }
}