import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_state.dart';

class AuthGuard {
  /// Checks if user is logged in.
  /// If YES: Runs [onAuthenticated].
  /// If NO: Shows a dialog prompting to login.
  static void run(
    BuildContext context, {
    required VoidCallback onAuthenticated,
  }) {
    final state = context.read<AuthBloc>().state;

    if (!state.isGuest) {
      // User is logged in, run the action immediately
      onAuthenticated();
    } else {
      // User is Guest, show dialog
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Account Required"),
          content: const Text("You need to sign in to use this feature."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx); // Close dialog
                context.push('/login'); // Go to login
              },
              child: const Text("Login / Sign Up"),
            ),
          ],
        ),
      );
    }
  }
}
