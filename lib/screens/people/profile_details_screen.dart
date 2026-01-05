import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:linguaflow/models/user_model.dart';
import 'package:linguaflow/utils/language_helper.dart';

class ProfileDetailsScreen extends StatelessWidget {
  final UserModel user;

  const ProfileDetailsScreen({Key? key, required this.user}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgDark = const Color(0xFF15161A);
    final cardColor = const Color(0xFF1E2025);
    final primaryPink = const Color(0xFFE91E63);

    return Scaffold(
      backgroundColor: bgDark,
      body: CustomScrollView(
        slivers: [
          // 1. App Bar with Profile Image
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            backgroundColor: bgDark,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: user.photoUrl ?? '',
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: cardColor),
                    errorWidget: (_, __, ___) => Container(color: cardColor, child: const Icon(Icons.person, size: 50, color: Colors.white)),
                  ),
                  // Gradient to make text readable
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black87],
                      ),
                    ),
                  ),
                ],
              ),
              title: Text(user.displayName),
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
                        _buildBadge("ONLINE", Colors.green),
                      if (user.isNewUser) ...[
                        const SizedBox(width: 8),
                        _buildBadge("NEW", Colors.teal),
                      ],
                      const Spacer(),
                      if (user.age != null)
                        Text("${user.age} years old", style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Location
                  if (user.city != null || user.country != null) ...[
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.grey, size: 16),
                        const SizedBox(width: 4),
                        Text(user.fullLocation, style: const TextStyle(color: Colors.white)),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Bio
                  const Text("About Me", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    user.bio ?? "No bio provided.",
                    style: const TextStyle(color: Colors.grey, height: 1.5),
                  ),
                  const SizedBox(height: 24),

                  // Languages
                  const Text("Languages", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _buildLangChip("Native", user.nativeLanguage, primaryPink),
                      ...user.targetLanguages.map((l) => _buildLangChip("Learns", l, Colors.blueAccent)),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Topics
                  if (user.topics.isNotEmpty) ...[
                    const Text("Interests", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: user.topics.map((t) => Chip(
                        label: Text(t),
                        backgroundColor: cardColor,
                        labelStyle: const TextStyle(color: Colors.white70),
                        side: BorderSide.none,
                      )).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // References
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("References", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      if (user.referenceCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                          child: Text("${user.referenceCount}", style: const TextStyle(color: Colors.white)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (user.references.isEmpty)
                    const Text("No references yet.", style: TextStyle(color: Colors.grey))
                  else
                    ...user.references.map((ref) => Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('"${ref.text}"', style: const TextStyle(color: Colors.white, fontStyle: FontStyle.italic)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 10,
                                backgroundImage: ref.authorPhotoUrl != null ? NetworkImage(ref.authorPhotoUrl!) : null,
                                child: ref.authorPhotoUrl == null ? const Icon(Icons.person, size: 10) : null,
                              ),
                              const SizedBox(width: 8),
                              Text(ref.authorName, style: TextStyle(color: primaryPink, fontWeight: FontWeight.bold)),
                              const Spacer(),
                              Icon(Icons.star, color: Colors.amber, size: 16),
                            ],
                          )
                        ],
                      ),
                    )),
                  
                  // Bottom Padding
                  const SizedBox(height: 80), 
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primaryPink,
        onPressed: () {
          // TODO: Implement Chat Logic
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Start chat with ${user.displayName}")));
        },
        icon: const Icon(Icons.chat_bubble_outline),
        label: const Text("Message"),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildLangChip(String prefix, String code, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2025),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(prefix, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(width: 8),
          Text(LanguageHelper.getFlagEmoji(code), style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 4),
          Text(LanguageHelper.getLanguageName(code), style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}