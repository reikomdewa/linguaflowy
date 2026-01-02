import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

// CONFIG
import 'package:linguaflow/app_router.dart';
import 'package:linguaflow/core/theme/app_theme.dart'; // <--- IMPORT THEME

// BLOCS
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_event.dart';
import 'package:linguaflow/blocs/auth/auth_state.dart';
import 'package:linguaflow/blocs/lesson/lesson_bloc.dart';
import 'package:linguaflow/blocs/quiz/quiz_bloc.dart';
import 'package:linguaflow/blocs/settings/settings_bloc.dart';

import 'package:linguaflow/blocs/speak/room/room_bloc.dart';
import 'package:linguaflow/blocs/speak/room/room_event.dart';
import 'package:linguaflow/blocs/speak/tutor/tutor_bloc.dart';
import 'package:linguaflow/blocs/speak/tutor/tutor_event.dart';
import 'package:linguaflow/blocs/vocabulary/vocabulary_bloc.dart';

// SERVICES
import 'package:linguaflow/services/auth_service.dart';
import 'package:linguaflow/services/speak/chat_service.dart';
import 'package:linguaflow/services/gemini_service.dart';
import 'package:linguaflow/services/lesson_service.dart';
import 'package:linguaflow/services/hybrid_lesson_service.dart';
import 'package:linguaflow/services/repositories/lesson_repository.dart';
import 'package:linguaflow/services/translation_service.dart';
import 'package:linguaflow/services/user_service.dart';
import 'package:linguaflow/services/vocabulary_service.dart';

// WIDGETS
import 'package:linguaflow/screens/home/widgets/audio_player_overlay.dart';
import 'package:linguaflow/screens/speak/active_screen/widgets/overlays/live_room_overlay.dart';

class LinguaflowApp extends StatelessWidget {
  const LinguaflowApp({super.key});

  @override
  Widget build(BuildContext context) {
    final lessonRepository = LessonRepository(
      firestoreService: LessonService(),
      localService: HybridLessonService(),
    );

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: lessonRepository),
        RepositoryProvider(create: (context) => AuthService()),
        RepositoryProvider(create: (context) => UserService()),
        RepositoryProvider(create: (context) => LessonService()),
        RepositoryProvider(create: (context) => VocabularyService()),
        RepositoryProvider(create: (context) => TranslationService()),
        RepositoryProvider(create: (context) => HybridLessonService()),
        RepositoryProvider(create: (context) => ChatService()),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => SettingsBloc()..add(LoadSettings()),
          ),
          BlocProvider(
            create: (context) => AuthBloc(
              context.read<AuthService>(),
              context.read<UserService>(),
            )..add(AuthCheckRequested()),
          ),
          BlocProvider<LessonBloc>(
            create: (context) => LessonBloc(
              geminiService: GeminiService(),
              lessonRepository: lessonRepository,
            ),
          ),
          BlocProvider<QuizBloc>(create: (context) => QuizBloc()),
          BlocProvider<RoomBloc>(
            create: (context) => RoomBloc()..add(const LoadRooms()),
          ),
          BlocProvider<TutorBloc>(
            create: (context) => TutorBloc()..add(const LoadTutors()),
          ),
          BlocProvider(
            create: (context) =>
                VocabularyBloc(context.read<VocabularyService>()),
          ),
        ],
        child: const LinguaflowAppView(),
      ),
    );
  }
}

class LinguaflowAppView extends StatefulWidget {
  const LinguaflowAppView({super.key});

  @override
  State<LinguaflowAppView> createState() => _LinguaflowAppViewState();
}

class _LinguaflowAppViewState extends State<LinguaflowAppView> {
  late final GoRouter _router;
  @override
  void initState() {
    super.initState();
    final authBloc = context.read<AuthBloc>();

    _router = GoRouter(
      navigatorKey: GlobalKey<NavigatorState>(),
      initialLocation: '/',
      refreshListenable: GoRouterRefreshStream(authBloc.stream),
      routes: AppRouter.router.configuration.routes,
      errorBuilder: (context, state) =>
          const Scaffold(body: Center(child: Text("Page not found"))),

      // --- UPDATE THIS SECTION ---
      redirect: (context, state) {
        final authState = authBloc.state;
        final bool isLoggedIn = authState is AuthAuthenticated;
        final bool isInitializing =
            authState is AuthInitial || authState is AuthLoading;
        final String location = state.uri.toString();
        final bool isLoggingIn = location == '/login';
        final bool isPlacementTest = location.startsWith(
          '/placement-test',
        ); // Optional: Allow placement test?

        // 1. Remove Splash Screen once Auth is determined
        if (!isInitializing) {
          FlutterNativeSplash.remove();
        }

        // 2. MOBILE SPECIFIC: FORCE LOGIN
        if (!kIsWeb) {
          // If NOT Web, NOT Logged in, NOT Initializing, and NOT already at Login
          if (!isLoggedIn &&
              !isInitializing &&
              !isLoggingIn &&
              !isPlacementTest) {
            return '/login';
          }
        }

        // 3. GENERAL: Prevent Logged-in users from seeing Login page
        if (isLoggedIn && isLoggingIn) {
          return '/';
        }

        return null; // Guest mode allowed on Web (fall-through)
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, settings) {
        return MaterialApp.router(
          title: 'LinguaFlow',
          debugShowCheckedModeBanner: false,

          // --- THEME USAGE ---
          themeMode: settings.themeMode,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,

          routerConfig: _router,

          builder: (context, child) {
            return Stack(
              children: [
                if (child != null) child,
                const AudioPlayerOverlay(),
                const LiveRoomOverlay(),
              ],
            );
          },
        );
      },
    );
  }
}

// Helper Class
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
      (dynamic _) => notifyListeners(),
    );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
// flutter build web --dart-define-from-file=config.json
// flutter run -d chrome --dart-define-from-file=config.json