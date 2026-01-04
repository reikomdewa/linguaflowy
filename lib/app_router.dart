import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:upgrader/upgrader.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
    navigatorKey: navigatorKey, // Ensure this is the GlobalKey form globals.dart
    initialLocation: '/',

    // 1. REFRESH LISTENABLE
    // This connects GoRouter to the AuthBloc. When the state changes,
    // the redirect logic is re-evaluated immediately.
    refreshListenable: GoRouterRefreshStream(authBloc.stream),

    // 2. REDIRECT LOGIC
    redirect: (context, state) {
      final authState = authBloc.state;
      final String location = state.uri.toString();

      // Status Checks
      final bool isLoggedIn = authState is AuthAuthenticated;
      final bool isInitializing = authState is AuthInitial || authState is AuthLoading;
      final bool isLoggingIn = location == '/login';
      final bool isPlacementTest = location.startsWith('/placement-test');

      // A. Handling Splash Screen & Initialization
      // If we are still loading the user, we DO NOT redirect yet.
      // This prevents the Home Screen from mounting and firing queries with null User.
      if (isInitializing) {
        return null; 
      }
      
      // Once we know the state (LoggedIn or Unauthenticated), remove native splash
      FlutterNativeSplash.remove();

      // B. Unauthenticated User Logic
      if (!isLoggedIn) {
        // Allow access to Login and Placement Test
        if (isLoggingIn || isPlacementTest) {
          return null;
        }
        // Redirect everything else to Login
        return '/login';
      }

      // C. Authenticated User Logic
      // If user is logged in but trying to go to login page, send to Home
      if (isLoggedIn && isLoggingIn) {
        return '/';
      }

      // D. Admin Route Protection
      if (location.startsWith('/admin')) {
         // You can add specific Admin checks here if your AuthState has an isAdmin field
         // if (!authState.isAdmin) return '/';
      }

      return null; // No redirect needed, proceed to route
    },

    // 3. ROUTE DEFINITIONS
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
          final bool? extraIsPremium = state.extra as bool?;
          return PremiumScreen(isPremium: extraIsPremium ?? false);
        },
      ),

      GoRoute(path: '/admin', builder: (context, state) => const AdminScreen()),

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