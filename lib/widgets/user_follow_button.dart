import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_state.dart';
import 'package:linguaflow/blocs/auth/auth_event.dart';

class UserFollowButton extends StatelessWidget {
  final String targetUserId;
  final Color? activeColor; // Color when not following (e.g., Blue/Black)

  const UserFollowButton({
    super.key,
    required this.targetUserId,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is! AuthAuthenticated) return const SizedBox.shrink();

        final currentUser = state.user;

        // 1. Don't show follow button for yourself
        if (currentUser.id == targetUserId) {
          return const SizedBox.shrink();
        }

        // 2. Check status
        final isFollowing = currentUser.following.contains(targetUserId);

        return GestureDetector(
          onTap: () {
            if (isFollowing) {
              context.read<AuthBloc>().add(AuthUnfollowUser(targetUserId));
            } else {
              context.read<AuthBloc>().add(AuthFollowUser(targetUserId));
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isFollowing
                  ? Colors.transparent
                  : (activeColor ?? theme.primaryColor),
              border: isFollowing
                  ? Border.all(color: theme.dividerColor)
                  : null,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isFollowing ? "Following" : "Follow",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isFollowing
                    ? theme.textTheme.bodyMedium?.color
                    : Colors.white, // Assuming primary color background needs white text
              ),
            ),
          ),
        );
      },
    );
  }
}