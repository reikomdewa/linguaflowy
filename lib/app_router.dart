import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/screens/login/web_login_layout.dart';
import 'package:upgrader/upgrader.dart';

// BLOCS
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_state.dart';
import 'package:linguaflow/blocs/lesson/lesson_bloc.dart';

// MODELS
import 'package:linguaflow/models/lesson_model.dart';

// --- SCREEN IMPORTS ---
import 'package:linguaflow/screens/main_navigation_screen.dart';
import 'package:linguaflow/screens/home/home_screen.dart';
import 'package:linguaflow/screens/login/login_screen.dart';
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
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();

  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',

    // --- REDIRECT LOGIC ---
    redirect: (context, state) {
      final authState = context.read<AuthBloc>().state;
      final bool isLoggedIn = authState is AuthAuthenticated;
      final String location = state.uri.toString();

      // 1. Prevent Logged-in users from seeing Login
      if (isLoggedIn && location == '/login') return '/';

      // 2. Protect Admin Routes
      if (location.startsWith('/admin') && !isLoggedIn) return '/login';

      return null;
    },

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
              final quizId = state.pathParameters['quizId']!;
              // Note: Ensure your QuizScreen constructor accepts the ID if needed.
              // e.g. return QuizScreen(quizId: quizId);
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
          // If on Web, show the Web Layout. If on Mobile, show Mobile Layout.
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
          // Expecting parameters passed via extra map
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
              return const SizedBox(); // Placeholder for LiveRoomScreen
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
          final userId = state.pathParameters['userId'];
          // Note: If you updated ProfileScreen to not take params, this is fine.
          // Otherwise pass: ProfileScreen(userId: userId)
          return const ProfileScreen();
        },
      ),

      GoRoute(
        path: '/premium',
        builder: (context, state) {
          // 1. Try to get it from the navigation 'extra'
          final bool? extraIsPremium = state.extra as bool?;

          // 2. Fallback: If 'extra' is lost (e.g. page refresh),
          // we can try to look at the AuthBloc state directly if available,
          // OR just default to false (safe approach).

          // Simple fix: Default to false if null
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
          // final type = state.pathParameters['type']!;
          // Try to get the actual list from extra
          final playlist = state.extra as List<LessonModel>? ?? [];
          return PlaylistScreen(playlist: playlist);
        },
      ),

      GoRoute(
        path: '/story-mode',
        builder: (context, state) {
          // Expecting a LessonModel in extra
          final lesson = state.extra as LessonModel?;
          return StoryModeScreen(lesson: lesson!);
        },
      ),
    ],

    errorBuilder: (context, state) =>
        const Scaffold(body: Center(child: Text("Page not found"))),
  );
}
