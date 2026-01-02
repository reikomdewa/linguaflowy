import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_state.dart';

// Screens
import 'package:linguaflow/screens/home/home_screen.dart';
import 'package:linguaflow/screens/login/login_screen.dart';
import 'package:linguaflow/screens/reader/reader_screen.dart';

class AppRouter {
  // We need a key to access the NavigatorState without context in some cases
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();

  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    
    // 1. Redirect Logic (Guards)
    // This runs on every navigation event
    redirect: (context, state) {
      final authState = context.read<AuthBloc>().state;
      final bool isLoggedIn = authState is AuthAuthenticated;
      
      final bool isLoggingIn = state.uri.toString() == '/login';

      // Example: Require login for specific paths (Optional)
      // If you want to force login for everything:
      // if (!isLoggedIn && !isLoggingIn) return '/login';
      
      // If logged in and trying to access login, go home
      if (isLoggedIn && isLoggingIn) return '/';

      return null; // No redirect needed
    },

    // 2. Define Routes
    routes: [
      // HOME ROUTE
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
        routes: [
          // SUB-ROUTE: Lesson Details
          // URL will be: /lesson/123
          GoRoute(
            path: 'lesson/:lessonId', // :userId indicates a variable
            builder: (context, state) {
              // Extract the ID from the URL
              final lessonId = state.pathParameters['lessonId'];
              // You usually pass the ID to the screen and let it fetch data
              // OR pass the object via 'extra' (but extra doesn't persist on Web refresh)
              return ReaderScreen( lesson: Lesson, lessonId: lessonId!);
            },
          ),
        ],
      ),

      // LOGIN ROUTE
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
    ],
    
    // Error Page (404)
    errorBuilder: (context, state) => const Scaffold(
      body: Center(child: Text('Page not found')),
    ),
  );
}