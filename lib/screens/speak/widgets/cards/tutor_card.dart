import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_state.dart';
import 'package:linguaflow/blocs/speak/speak_bloc.dart';
import 'package:linguaflow/blocs/speak/speak_event.dart';
import 'package:linguaflow/models/speak/speak_models.dart';

class TutorCard extends StatelessWidget {
  final Tutor tutor;

  const TutorCard({super.key, required this.tutor});

  void _showOptionsMenu(BuildContext context, bool isMe) {
    final speakBloc = context.read<SpeakBloc>();
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      useSafeArea: true, // Ensures it doesn't overlap system bars
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.favorite_rounded, color: Colors.red),
                title: const Text("Add to Favorites"),
                onTap: () {
                  speakBloc.add(ToggleFavoriteTutor(tutor.id));
                  Navigator.pop(ctx);
                },
              ),
              if (isMe) ...[
                const Divider(),
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.red,
                  ),
                  title: const Text(
                    "Delete Tutor Profile",
                    style: TextStyle(color: Colors.red),
                  ),
                  subtitle: const Text("This action cannot be undone"),
                  onTap: () {
                    // Logic for deletion (You might need a DeleteTutorProfile event in your Bloc)
                    _showDeleteConfirmation(context, speakBloc);
                  },
                ),
              ],
              ListTile(
                leading: const Icon(Icons.report_problem_outlined),
                title: const Text("Report Tutor"),
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, SpeakBloc bloc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Profile?"),
        content: const Text(
          "Are you sure you want to remove your tutor profile from the platform?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
               bloc.add(DeleteTutorProfileEvent(tutor.id));
              Navigator.pop(ctx); // Close Dialog
              Navigator.pop(context); // Close BottomSheet
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = context.read<AuthBloc>().state;

    // Check if this card belongs to the logged-in user
    bool isMe = false;
    if (authState is AuthAuthenticated) {
      isMe = authState.user.id == tutor.userId;
    }

    // Dynamic data from the model
    final String name = tutor.name;
    final String language = tutor.language;
    final double rating = tutor.rating;
    final int reviews = tutor.reviews;
    final double price = tutor.pricePerHour;
    final String imageUrl = tutor.imageUrl;
    final String level = tutor.level;
    final List<String> specialties = tutor.specialties;

    final bool isOnline = tutor.isOnline;
    final bool isSuperTutor = tutor.isSuperTutor;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: theme.cardColor,
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Picture
                  Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 32,
                          backgroundColor: theme.primaryColor.withOpacity(0.1),
                          backgroundImage: NetworkImage(imageUrl),
                          onBackgroundImageError: (_, __) =>
                              const Icon(Icons.person),
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
                              border: Border.all(
                                color: theme.cardColor,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),

                  // Info Section
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            if (isSuperTutor)
                              _buildBadge("SUPER", Colors.amber),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                "Teaches $language",
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        _buildBadge(level, theme.primaryColor),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 18,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              rating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "($reviews reviews)",
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.hintColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // OPTIONS ICON
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    color: theme.hintColor,
                    onPressed: () => _showOptionsMenu(context, isMe),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              Column(
                children: [
                  const SizedBox(height: 12),
                  Text(
                    tutor.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (specialties.isNotEmpty) ...[
                Wrap(
                  spacing: 6,
                  children: specialties
                      .take(3)
                      .map(
                        (s) => Text(
                          "#$s",
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
              const SizedBox(height: 16),
              Divider(height: 1, color: Colors.grey.withOpacity(0.1)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "\$${price.toStringAsFixed(2)}",
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.primaryColor,
                        ),
                      ),
                      Text(
                        "per 50-min lesson",
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.hintColor,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,

                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
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

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
