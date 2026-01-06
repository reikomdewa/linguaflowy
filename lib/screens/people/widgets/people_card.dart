import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:linguaflow/models/user_model.dart';
import 'package:linguaflow/utils/language_helper.dart';

class PeopleCard extends StatelessWidget {
  final UserModel user;
  final VoidCallback onTap;
  final Color cardColor;
  final Color primaryColor;

  const PeopleCard({
    Key? key,
    required this.user,
    required this.onTap,
    // Defaults are just fallbacks; normally passed by parent based on Theme
    this.cardColor = const Color(0xFF1E2025),
    this.primaryColor = const Color(0xFFE91E63),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // --- THEME DATA ---
    final theme = Theme.of(context);
    final textColor =
        theme.colorScheme.onSurface; // Black (Light), White (Dark)
    final subTextColor = theme.hintColor; // Grey

    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          // Optional: Add shadow in light mode for better visibility
          boxShadow: theme.brightness == Brightness.light
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Avatar & Status
            _buildAvatar(theme),
            const SizedBox(width: 12),

            // 2. Info Column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderRow(textColor, subTextColor),
                  const SizedBox(height: 6),
                  _buildBio(subTextColor),
                  const SizedBox(height: 12),
                  _buildLanguagesRow(textColor, subTextColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(ThemeData theme) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: user.photoUrl ?? '',
            width: 90,
            height: 90,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(color: theme.dividerColor),
            errorWidget: (context, url, error) => Container(
              width: 90,
              height: 90,
              color: theme.dividerColor,
              child: Icon(Icons.person, color: theme.hintColor),
            ),
          ),
        ),
        // Streak Badge
        if (user.isPremium)
          Positioned(
            top: 4,
            left: 4,
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

  Widget _buildHeaderRow(Color textColor, Color subTextColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.age != null
                    ? "${user.displayName}, ${user.age}"
                    : user.displayName,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              if (user.city != null || user.country != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2.0),
                  child: Text(
                    user.fullLocation,
                    style: TextStyle(color: subTextColor, fontSize: 13),
                  ),
                ),
            ],
          ),
        ),
        // Badges
        if (user.isNewUser)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.teal,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              "NEW",
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          )
        else if (user.referenceCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              // Adaptive background for the badge
              color: textColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Text(
                  "${user.referenceCount}",
                  style: TextStyle(
                    color: textColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                // Icon uses the primary color (HyperBlue/Pink)
                Icon(Icons.format_quote, color: primaryColor, size: 14),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildBio(Color subTextColor) {
    if (user.bio == null || user.bio!.isEmpty) return const SizedBox.shrink();
    return Text(
      user.bio!,
      style: TextStyle(color: subTextColor, fontSize: 13, height: 1.3),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildLanguagesRow(Color textColor, Color subTextColor) {
    return Row(
      children: [
        // Native
        _buildLangBadge(
          "FLUENT",
          user.nativeLanguage,
          null,
          textColor,
          subTextColor,
        ),
        const SizedBox(width: 12),

        // Target Language
        if (user.targetLanguages.isNotEmpty)
          _buildLangBadge(
            "LEARNS",
            user.targetLanguages.first,
            user.languageLevels[user.targetLanguages.first],
            textColor,
            subTextColor,
          ),
      ],
    );
  }

  Widget _buildLangBadge(
    String label,
    String langCode,
    String? level,
    Color textColor,
    Color subTextColor,
  ) {
    final flag = LanguageHelper.getFlagEmoji(langCode);
    final shortLevel = level?.split(' ').first ?? "";

    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: subTextColor, // Subtle label color (grey)
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            if (shortLevel.isNotEmpty)
              Text(
                shortLevel,
                style: TextStyle(
                  color: primaryColor, // Level in Accent Color
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        const SizedBox(width: 6),
        Text(flag, style: const TextStyle(fontSize: 18)),
      ],
    );
  }
}
