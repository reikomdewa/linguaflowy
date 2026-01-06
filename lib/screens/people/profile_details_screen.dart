import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_event.dart';
import 'package:linguaflow/blocs/auth/auth_state.dart';
import 'package:linguaflow/models/user_model.dart';
import 'package:linguaflow/screens/inbox/private_chat_screen.dart';
import 'package:linguaflow/utils/language_helper.dart';

class ProfileDetailsScreen extends StatelessWidget {
  final UserModel user;

  const ProfileDetailsScreen({Key? key, required this.user}) : super(key: key);

  // Helper to generate a consistent Chat ID between two users
  String _getChatId(String currentUserId, String otherUserId) {
    final List<String> ids = [currentUserId, otherUserId];
    ids.sort(); // Sort alphabetically to ensure ID is always "userA_userB"
    return ids.join('_');
  }

  @override
  Widget build(BuildContext context) {
    // --- THEME DATA ---
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Dynamic Colors
    final scaffoldBg = theme.scaffoldBackgroundColor;
    final cardColor = theme.cardColor;
    final textColor = theme.colorScheme.onSurface;
    final subTextColor = theme.hintColor;
    final primaryColor = theme.colorScheme.secondary; // HyperBlue/Pink
    final borderColor = theme.dividerColor;

    // Get Current User for Logic
    final authState = context.watch<AuthBloc>().state;
    UserModel? currentUser;
    if (authState is AuthAuthenticated) {
      currentUser = authState.user;
    }

    // Don't show buttons if looking at own profile
    final isMe = currentUser?.id == user.id;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: CustomScrollView(
        slivers: [
          // 1. App Bar with Profile Image
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            backgroundColor: scaffoldBg,
            foregroundColor: textColor,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: user.photoUrl ?? '',
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: cardColor),
                    errorWidget: (_, __, ___) => Container(
                      color: cardColor,
                      child: Icon(Icons.person, size: 50, color: subTextColor),
                    ),
                  ),
                  // Gradient
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          scaffoldBg.withOpacity(0.8),
                          scaffoldBg,
                        ],
                        stops: const [0.6, 0.9, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
              title: Text(user.displayName, style: TextStyle(color: textColor)),
              centerTitle: true,
            ),
          ),

          // 2. Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Row
                  Row(
                    children: [
                      if (user.isOnline)
                        _buildBadge("ONLINE", Colors.green, theme),
                      if (user.isNewUser) ...[
                        const SizedBox(width: 8),
                        _buildBadge("NEW", Colors.teal, theme),
                      ],
                      const Spacer(),
                      if (user.age != null)
                        Text(
                          "${user.age} years old",
                          style: TextStyle(color: subTextColor),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // --- FOLLOW BUTTON (New) ---
                  if (!isMe && currentUser != null) ...[
                    BlocBuilder<AuthBloc, AuthState>(
                      builder: (context, state) {
                        final isFollowing = currentUser!.following.contains(
                          user.id,
                        );

                        return SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              if (isFollowing) {
                                context.read<AuthBloc>().add(
                                  AuthUnfollowUser(user.id),
                                );
                              } else {
                                context.read<AuthBloc>().add(
                                  AuthFollowUser(user.id),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isFollowing
                                  ? cardColor
                                  : primaryColor,
                              foregroundColor: isFollowing
                                  ? textColor
                                  : Colors.white,
                              elevation: 0,
                              side: isFollowing
                                  ? BorderSide(color: borderColor)
                                  : BorderSide.none,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              isFollowing ? "Following" : "Follow",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Location
                  if (user.city != null || user.country != null) ...[
                    Row(
                      children: [
                        Icon(Icons.location_on, color: subTextColor, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          user.fullLocation,
                          style: TextStyle(color: textColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Bio
                  Text(
                    "About Me",
                    style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user.bio ?? "No bio provided.",
                    style: TextStyle(color: subTextColor, height: 1.5),
                  ),
                  const SizedBox(height: 24),

                  // Languages
                  Text(
                    "Languages",
                    style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _buildLangChip(
                        "Native",
                        user.nativeLanguage,
                        primaryColor,
                        theme,
                      ),
                      ...user.targetLanguages.map(
                        (l) => _buildLangChip(
                          "Learns",
                          l,
                          isDark ? Colors.blueAccent : Colors.blue[700]!,
                          theme,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Topics
                  if (user.topics.isNotEmpty) ...[
                    Text(
                      "Interests",
                      style: TextStyle(
                        color: textColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: user.topics
                          .map(
                            (t) => Chip(
                              label: Text(t),
                              backgroundColor: cardColor,
                              labelStyle: TextStyle(
                                color: textColor.withOpacity(0.8),
                              ),
                              side: BorderSide(color: borderColor),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // References
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "References",
                        style: TextStyle(
                          color: textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (user.referenceCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: textColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            "${user.referenceCount}",
                            style: TextStyle(color: textColor),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (user.references.isEmpty)
                    Text(
                      "No references yet.",
                      style: TextStyle(color: subTextColor),
                    )
                  else
                    ...user.references.map(
                      (ref) => Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '"${ref.text}"',
                              style: TextStyle(
                                color: textColor,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 10,
                                  backgroundImage: ref.authorPhotoUrl != null
                                      ? NetworkImage(ref.authorPhotoUrl!)
                                      : null,
                                  backgroundColor: borderColor,
                                  child: ref.authorPhotoUrl == null
                                      ? Icon(
                                          Icons.person,
                                          size: 12,
                                          color: subTextColor,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  ref.authorName,
                                  style: TextStyle(
                                    color: primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                const Icon(
                                  Icons.star,
                                  color: Colors.amber,
                                  size: 16,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
      // --- MESSAGE FAB (Fixed) ---
      floatingActionButton: !isMe
          ? FloatingActionButton.extended(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              onPressed: () {
                if (currentUser == null) return;

                // 1. Generate Chat ID
                final chatId = _getChatId(currentUser.id, user.id);

                // 2. Navigate
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PrivateChatScreen(
                      chatId: chatId,
                      otherUserName: user.displayName,
                      otherUserPhoto: user.photoUrl,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text("Message"),
            )
          : null, // Hide FAB if it's my own profile
    );
  }

  Widget _buildBadge(String text, Color color, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildLangChip(
    String prefix,
    String code,
    Color accentColor,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(prefix, style: TextStyle(color: theme.hintColor, fontSize: 12)),
          const SizedBox(width: 8),
          Text(
            LanguageHelper.getFlagEmoji(code),
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(width: 4),
          Text(
            LanguageHelper.getLanguageName(code),
            style: TextStyle(color: accentColor, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
