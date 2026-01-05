import 'dart:async';
import 'package:flutter/foundation.dart'; // Required for kIsWeb
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:linguaflow/screens/profile/edit_profile_screen.dart';
import 'package:upgrader/upgrader.dart';

// GLOBALS
import 'package:linguaflow/core/globals.dart';

// BLOCS
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_state.dart';

// MODELS
import 'package:linguaflow/models/lesson_model.dart';

// --- SCREEN IMPORTS ---
import 'package:linguaflow/screens/main_navigation_screen.dart';
import 'package:linguaflow/screens/login/login_screen.dart';
import 'package:linguaflow/screens/login/web_login_layout.dart';
import 'package:linguaflow/screens/reader/reader_screen_wraper.dart';

import 'package:linguaflow/screens/admin/admin_screen.dart';
import 'package:linguaflow/screens/community/community_screen.dart';
import 'package:linguaflow/screens/discover/discover_screen.dart';
import 'package:linguaflow/screens/inbox/inbox_screen.dart';
import 'package:linguaflow/screens/learn/learn_screen.dart';
import 'package:linguaflow/screens/library/library_screen.dart';
import 'package:linguaflow/screens/placement_test/placement_test_screen.dart';
import 'package:linguaflow/screens/playlist/playlist_screen.dart';
import 'package:linguaflow/screens/premium/premium_screen.dart';
import 'package:linguaflow/screens/profile/profile_screen.dart';
import 'package:linguaflow/screens/quiz/quiz_screen.dart';
import 'package:linguaflow/screens/speak/speak_screen.dart';
import 'package:linguaflow/screens/story_mode/story_mode_screen.dart';
import 'package:linguaflow/screens/vocabulary/vocabulary_screen.dart';

class AppRouter {
  final AuthBloc authBloc;

  AppRouter(this.authBloc);

  late final GoRouter router = GoRouter(
    navigatorKey: navigatorKey, // From globals.dart
    initialLocation: '/',

    // 1. REFRESH LISTENABLE
    // This makes the Router "Reactive". It will re-run the redirect logic
    // whenever the AuthBloc state changes (e.g. Loading -> Authenticated).
    refreshListenable: GoRouterRefreshStream(authBloc.stream),

    // 2. REDIRECT LOGIC
    redirect: (context, state) {
      final authState = authBloc.state;
      final String location = state.uri.toString();

      // Check Status
      final bool isLoggedIn = authState is AuthAuthenticated;
      final bool isInitializing =
          authState is AuthInitial || authState is AuthLoading;
      final bool isLoggingIn = location == '/login';
      final bool isPlacementTest = location.startsWith('/placement-test');

      // A. WAIT FOR AUTH INITIALIZATION
      // If we are still checking if the user is logged in, DO NOT load the UI yet.
      // This prevents "Permission Denied" crashes on startup.
      if (isInitializing) {
        return null; // Stay on Splash / Current Screen
      }

      // Once initialized, remove the native splash screen
      FlutterNativeSplash.remove();

      // B. LOGGED OUT USERS
      if (!isLoggedIn) {
        // 1. Always allow Login page and Placement Test
        if (isLoggingIn || isPlacementTest) {
          return null;
        }

        // 2. WEB GUEST MODE (FIX)
        // If on Web, we allow guests to browse the app (Home, etc.)
        // without being forced to login.
        if (kIsWeb) {
          return null;
        }

        // 3. MOBILE FORCED LOGIN
        // If on Mobile, force them to login (unless you want guests there too).
        return '/login';
      }

      // C. LOGGED IN USERS
      // If user is already logged in but on the Login page, send them Home.
      if (isLoggedIn && isLoggingIn) {
        return '/';
      }

      // D. ADMIN PROTECTION
      // (Optional) Add check here if you have an isAdmin flag in your state
      if (location.startsWith('/admin')) {
        // if (!authState.isAdmin) return '/';
      }

      return null; // Allow navigation
    },

    // 3. ROUTES
    routes: [
      // =========================================================
      // ROOT / MAIN TABS
      // =========================================================
      GoRoute(
        path: '/',
        builder: (context, state) {
          return UpgradeAlert(child: const MainNavigationScreen());
        },
        routes: [
          // READER: /lesson/123
          GoRoute(
            path: 'lesson/:id',
            builder: (context, state) {
              final lessonId = state.pathParameters['id']!;
              final extra = state.extra as LessonModel?;
              return ReaderScreenWrapper(
                lessonId: lessonId,
                initialLesson: extra,
              );
            },
          ),

          // QUIZ: /quiz/abc
          GoRoute(
            path: 'quiz/:quizId',
            builder: (context, state) {
              // final quizId = state.pathParameters['quizId']!;
              return const QuizScreen();
            },
          ),
        ],
      ),

      // =========================================================
      // AUTH & ONBOARDING
      // =========================================================
      GoRoute(
        path: '/login',
        builder: (context, state) {
          if (kIsWeb) {
            return const WebLoginLayout();
          } else {
            return const LoginScreen();
          }
        },
      ),

      GoRoute(
        path: '/placement-test',
        builder: (context, state) {
          final map = state.extra as Map<String, dynamic>? ?? {};
          return PlacementTestScreen(
            nativeLanguage: map['nativeLanguage'] ?? '',
            targetLanguage: map['targetLanguage'] ?? '',
            targetLevelToCheck: map['targetLevelToCheck'] ?? '',
            userId: map['userId'] ?? '',
          );
        },
      ),

      // =========================================================
      // CORE FEATURES
      // =========================================================
      GoRoute(path: '/learn', builder: (context, state) => const LearnScreen()),
      GoRoute(
        path: '/discover',
        builder: (context, state) => const DiscoverScreen(),
      ),
      GoRoute(
        path: '/library',
        builder: (context, state) => const LibraryScreen(),
      ),
      GoRoute(
        path: '/vocabulary',
        builder: (context, state) => const VocabularyScreen(),
      ),

      // =========================================================
      // SPEAK & COMMUNITY
      // =========================================================
      GoRoute(
        path: '/speak',
        builder: (context, state) => const SpeakScreen(),
        routes: [
          GoRoute(
            path: 'room/:roomId',
            builder: (context, state) {
              return const SizedBox(); // Placeholder logic
            },
          ),
        ],
      ),

      GoRoute(
        path: '/community',
        builder: (context, state) => const CommunityScreen(),
      ),
      GoRoute(path: '/inbox', builder: (context, state) => const InboxScreen()),

      // =========================================================
      // USER & SETTINGS
      // =========================================================
      GoRoute(
        path: '/profile/:userId',
        builder: (context, state) {
          // final userId = state.pathParameters['userId'];
          return const ProfileScreen();
        },
      ),

      GoRoute(
        path: '/premium',
        builder: (context, state) {
          // 1. Get the Source of Truth (AuthBloc)
          final authState = context.read<AuthBloc>().state;

          // 2. Check if user is logged in
          if (authState is AuthAuthenticated) {
            // 3. Pass the FULL User object to the screen
            return PremiumScreen(user: authState.user);
          }

          // 4. Fallback if not logged in
          return const LoginScreen();
        },
      ),

      GoRoute(path: '/admin', builder: (context, state) => const AdminScreen()),
      GoRoute(
        path: '/edit_profile',
        builder: (context, state) => const EditProfileScreen(),
      ),

      // =========================================================
      // MEDIA & OTHERS
      // =========================================================
      GoRoute(
        path: '/playlist/:type',
        builder: (context, state) {
          final playlist = state.extra as List<LessonModel>? ?? [];
          return PlaylistScreen(playlist: playlist);
        },
      ),

      GoRoute(
        path: '/story-mode',
        builder: (context, state) {
          final lesson = state.extra as LessonModel?;
          return StoryModeScreen(lesson: lesson!);
        },
      ),
    ],

    errorBuilder: (context, state) =>
        const Scaffold(body: Center(child: Text("Page not found"))),
  );
}

// =================================================================
// HELPER CLASS
// Converts Stream to Listenable for GoRouter
// =================================================================
class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<dynamic> _subscription;

  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
      (dynamic _) => notifyListeners(),
    );
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
