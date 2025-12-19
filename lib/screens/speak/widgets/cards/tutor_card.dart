import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class TutorCard extends StatelessWidget {
  const TutorCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // THEME ACCESS

    const String name = "Sarah Jenkins";
    const String language = "English (Native)";
    const double rating = 4.9;
    const int reviews = 128;
    const double price = 15.00;
    const String imageUrl = "https://i.pravatar.cc/150?u=sarah";
    const bool isOnline = true;
    const bool isSuperTutor = true;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: theme.cardColor, // THEME COLOR
      child: InkWell(
        onTap: () {
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey.withOpacity(0.2), width: 1),
                        ),
                        child: CircleAvatar(
                          radius: 32,
                          backgroundImage: const NetworkImage(imageUrl),
                          onBackgroundImageError: (_, __) => const Icon(Icons.person),
                        ),
                      ),
                      if (isOnline)
                        Positioned(
                          right: 2,
                          bottom: 2,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              border: Border.all(color: theme.cardColor, width: 2), // THEME COLOR
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith( // THEME STYLE
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.verified, size: 16, color: Colors.blue),
                            if (isSuperTutor) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  "SUPER",
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.amber),
                                ),
                              )
                            ]
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(FontAwesomeIcons.language, size: 12, color: theme.hintColor), // THEME COLOR
                            const SizedBox(width: 6),
                            Text(
                              "Teaches $language",
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor), // THEME STYLE
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, size: 18, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text(
                              "$rating",
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "($reviews reviews)",
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor), // THEME STYLE
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.favorite_border),
                    color: theme.hintColor, // THEME COLOR
                    onPressed: () {},
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(height: 1, color: Colors.grey.withOpacity(0.2)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "\$${price.toStringAsFixed(2)}",
                        style: theme.textTheme.titleLarge?.copyWith( // THEME STYLE
                          fontWeight: FontWeight.bold,
                          color: theme.primaryColor,
                        ),
                      ),
                      Text(
                        "per 50-min lesson",
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor), // THEME STYLE
                      ),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor, // THEME COLOR
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text(
                      "Book Trial",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}