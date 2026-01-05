import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:linguaflow/models/user_model.dart';
import 'package:linguaflow/utils/language_helper.dart'; // Import Helper

class PeopleCard extends StatelessWidget {
  final UserModel user;
  final VoidCallback onTap;
  final Color cardColor;
  final Color primaryColor;

  const PeopleCard({
    Key? key,
    required this.user,
    required this.onTap,
    this.cardColor = const Color(0xFF1E2025),
    this.primaryColor = const Color(0xFFE91E63),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Avatar & Status
            _buildAvatar(),
            const SizedBox(width: 12),
            
            // 2. Info Column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderRow(),
                  const SizedBox(height: 6),
                  _buildBio(),
                  const SizedBox(height: 12),
                  _buildLanguagesRow(),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: user.photoUrl ?? '',
            width: 90,
            height: 90,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(color: Colors.grey[800]),
            errorWidget: (context, url, error) => Container(
              width: 90, height: 90,
              color: Colors.grey[800],
              child: const Icon(Icons.person, color: Colors.white),
            ),
          ),
        ),
        // Streak Badge
        Positioned(
          top: 4, left: 4,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: user.streakDays > 0 ? primaryColor : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: user.streakDays > 0 
              ? const Icon(Icons.flash_on, color: Colors.white, size: 12)
              : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.age != null ? "${user.displayName}, ${user.age}" : user.displayName,
                style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16
                ),
                overflow: TextOverflow.ellipsis,
              ),
              if (user.city != null || user.country != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2.0),
                  child: Text(
                    user.fullLocation,
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ),
            ],
          ),
        ),
        // Badges
        if (user.isNewUser)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: Colors.teal, borderRadius: BorderRadius.circular(4)),
            child: const Text("NEW", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          )
        else if (user.referenceCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: Colors.blueGrey[800], borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Text("${user.referenceCount}", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(width: 4),
                const Icon(Icons.format_quote, color: Colors.lightBlueAccent, size: 14),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildBio() {
    if (user.bio == null || user.bio!.isEmpty) return const SizedBox.shrink();
    return Text(
      user.bio!,
      style: TextStyle(color: Colors.grey[400], fontSize: 13, height: 1.3),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildLanguagesRow() {
    return Row(
      children: [
        _buildLangBadge("FLUENT", user.nativeLanguage),
        const SizedBox(width: 12),
        if (user.targetLanguages.isNotEmpty)
          _buildLangBadge("LEARNS", user.targetLanguages.first),
      ],
    );
  }

  Widget _buildLangBadge(String label, String langCode) {
    // USE LANGUAGE HELPER HERE
    final flag = LanguageHelper.getFlagEmoji(langCode);
    
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        const SizedBox(width: 6),
        Text(flag, style: const TextStyle(fontSize: 18)),
      ],
    );
  }
}