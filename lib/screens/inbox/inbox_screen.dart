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
  String? _selectedChatId;
  String? _selectedChatName;
  String? _selectedChatPhoto;

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final theme = Theme.of(context);

    if (authState is! AuthAuthenticated || authState.isGuest) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_person, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text("Inbox is unavailable for guests"),
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
      appBar: MediaQuery.of(context).size.width < 800
          ? AppBar(title: const Text("Messages"))
          : null,
      body: StreamBuilder<List<PrivateConversation>>(
        // CRITICAL: Ensure this service method queries "participants array-contains myId"
        stream: PrivateChatService().getInbox(myUser.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

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

          return LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 800;

              final Widget chatList = ListView.separated(
                padding: isDesktop
                    ? const EdgeInsets.only(top: 10)
                    : EdgeInsets.zero,
                itemCount: chats.length,
                separatorBuilder: (_, __) => const SizedBox.shrink(),
                itemBuilder: (context, index) {
                  final chat = chats[index];

                  // Identify the "Other User"
                  final otherId = chat.participants.firstWhere(
                    (id) => id != myUser.id,
                    orElse: () =>
                        chat.participants.first, // Fallback for self-chat
                  );
                  final otherData = chat.participantData[otherId] ?? {};
                  final name = otherData['name'] ?? 'User';
                  final photo = otherData['photo'];

                  // Message Status Logic
                  final bool isLastMsgFromMe = chat.lastSenderId == myUser.id;
                  final bool isUnread = !isLastMsgFromMe && !chat.isRead;

                  // Format the subtitle text
                  String subtitleText = chat.lastMessage;
                  if (isLastMsgFromMe) {
                    subtitleText = subtitleText;
                  }

                  return ListTile(
                    key: ValueKey(chat.id),
                    selected: isDesktop && _selectedChatId == chat.id,
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
                      subtitleText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: isUnread
                            ? FontWeight.w800
                            : FontWeight.normal,
                        color: isUnread ? theme.primaryColor : theme.hintColor,
                        // Italicize "You sent..." messages slightly to distinguish
                        fontStyle: isLastMsgFromMe
                            ? FontStyle.italic
                            : FontStyle.normal,
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
                        setState(() {
                          _selectedChatId = chat.id;
                          _selectedChatName = name;
                          _selectedChatPhoto = photo;
                        });
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
