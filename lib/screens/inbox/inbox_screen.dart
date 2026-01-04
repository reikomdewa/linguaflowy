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

    // Safety check
    if (myUser.id.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      // Only show main AppBar on Mobile. On Desktop, the list is just a sidebar.
      appBar: MediaQuery.of(context).size.width < 800
          ? AppBar(title: const Text("Messages"))
          : null,
      body: StreamBuilder<List<PrivateConversation>>(
        stream: PrivateChatService().getInbox(myUser.id),
        builder: (context, snapshot) {
          // 2. LOADING
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // 3. ERROR
          if (snapshot.hasError) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              FocusScope.of(context).unfocus();
            });
            debugPrint("❌ Inbox Query Error: ${snapshot.error}");
            return Center(
              child: Text("Error loading chats: ${snapshot.error}"),
            );
          }

          // 4. EMPTY
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 64,
                    color: theme.hintColor,
                  ),
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
                // On desktop, add top padding since we removed the AppBar
                padding: isDesktop
                    ? const EdgeInsets.only(top: 10)
                    : EdgeInsets.zero,
                itemCount: chats.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final chat = chats[index];
                  final otherId = chat.participants.firstWhere(
                    (id) => id != myUser.id,
                    orElse: () => '',
                  );
                  final otherData = chat.participantData[otherId] ?? {};
                  final name = otherData['name'] ?? 'User';
                  final photo = otherData['photo'];

                  final bool isLastMsgFromMe = chat.lastSenderId == myUser.id;
                  final bool isRead = chat.isRead;
                  final bool isUnread = !isLastMsgFromMe && !isRead;

                  final bool isSelected = _selectedChatId == chat.id;

                  return ListTile(
                    key: ValueKey(chat.id),
                    // Highlight selected item on Desktop
                    selected: isDesktop && isSelected,
                    selectedTileColor: theme.colorScheme.primary.withOpacity(
                      0.1,
                    ),
                    leading: CircleAvatar(
                      backgroundImage: photo != null
                          ? NetworkImage(photo)
                          : null,
                      child: photo == null
                          ? Text(name.isNotEmpty ? name[0] : '?')
                          : null,
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      chat.lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: isUnread
                            ? FontWeight.w800
                            : FontWeight.normal,
                        color: isUnread ? theme.primaryColor : theme.hintColor,
                      ),
                    ),
                    trailing: isUnread
                        ? Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: theme.primaryColor,
                              shape: BoxShape.circle,
                            ),
                          )
                        : null,
                    onTap: () {
                      if (isDesktop) {
                        // Desktop: Update State
                        setState(() {
                          _selectedChatId = chat.id;
                          _selectedChatName = name;
                          _selectedChatPhoto = photo;
                        });
                      } else {
                        // Mobile: Navigate
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
                    // Left Panel (List)
                    SizedBox(
                      width: 350, // Fixed width like WhatsApp Web
                      child: Column(
                        children: [
                          // Custom Header for Left Panel
                          Container(
                            height: kToolbarHeight,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            color: theme.scaffoldBackgroundColor,
                            child: const Text(
                              "Messages",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const Divider(height: 1),
                          Expanded(child: chatList),
                        ],
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    // Right Panel (Chat)
                    Expanded(
                      child: _selectedChatId != null
                          ? PrivateChatScreen(
                              // KEY IS CRITICAL: Forces Flutter to rebuild
                              // the widget when switching chats
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

  // Placeholder when no chat is selected on Desktop
  Widget _buildDesktopPlaceholder(ThemeData theme) {
    return Container(
      color: theme.brightness == Brightness.dark
          ? Colors.black12
          : Colors.grey[50],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.forum_outlined, size: 80, color: theme.disabledColor),
            const SizedBox(height: 20),
            Text(
              "Select a conversation",
              style: TextStyle(fontSize: 22, color: theme.disabledColor),
            ),
          ],
        ),
      ),
    );
  }
}
