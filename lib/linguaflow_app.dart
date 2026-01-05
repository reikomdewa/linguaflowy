import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:linguaflow/core/globals.dart';
import 'package:linguaflow/core/theme/app_theme.dart';

// CONFIG
// IMPORT THE APP ROUTER WE JUST CREATED
import 'package:linguaflow/app_router.dart';

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
    // 1. Initialize Repositories
    final lessonRepository = LessonRepository(
      firestoreService: LessonService(),
      localService: HybridLessonService(),
    );

    // 2. MultiRepositoryProvider (Dependency Injection)
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
      // 3. MultiBlocProvider (State Management)
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => SettingsBloc()..add(LoadSettings()),
          ),
          // AUTH BLOC: Created here, starts checking auth immediately
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
        // 4. Pass execution to the View, which holds the Router
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
  // Instance of the Router class we created in app_router.dart
  late final AppRouter _appRouter;

  @override
  void initState() {
    super.initState();
    // 5. Initialize the Router using the AuthBloc from Context
    // This is the critical connection point.
    _appRouter = AppRouter(context.read<AuthBloc>());
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, settings) {
        return MaterialApp.router(
          // 6. Use the router configuration from our instance
          routerConfig: _appRouter.router,
              scaffoldMessengerKey: rootScaffoldMessengerKey,
          title: 'LinguaFlow',
          debugShowCheckedModeBanner: false,

          // THEME
          themeMode: settings.themeMode,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,

          // OVERLAYS (Audio Player, Live Rooms)
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