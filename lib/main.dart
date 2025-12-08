import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:linguaflow/blocs/quiz/quiz_bloc.dart';
import 'package:linguaflow/blocs/settings/settings_bloc.dart';
import 'package:linguaflow/screens/main_navigation_screen.dart';
import 'package:linguaflow/services/gemini_service.dart';
import 'package:linguaflow/services/local_lesson_service.dart';
import 'package:linguaflow/services/repositories/lesson_repository.dart';

// Import all screens and services
import 'screens/auth/login_screen.dart';

import 'services/auth_service.dart';
import 'services/lesson_service.dart';
import 'services/vocabulary_service.dart';
import 'services/translation_service.dart';
import 'blocs/auth/auth_bloc.dart';
import 'blocs/lesson/lesson_bloc.dart';
import 'blocs/vocabulary/vocabulary_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  // Enable verbose logging
  await dotenv.load(fileName: ".env");
  final apiKey = dotenv.env['GEMINI_API_KEY'];

  if (apiKey != null) {
    Gemini.init(
      apiKey: apiKey,
      // --- ADD THIS ---
      // This prints the exact API URL and Response to the console.
      // It helps confirm if the package is using 'v1beta' or 'v1',
      // and shows the raw error details from Google.
    );
  } else {
    print("WARNING: GEMINI_API_KEY is missing in .env");
  }

  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.ryanheise.bg_demo.channel.audio',
    androidNotificationChannelName: 'Audio playback',
    androidNotificationOngoing: true,
    notificationColor: const Color(0xFF6A11CB),
    androidNotificationIcon: 'mipmap/ic_launcher',
  );

  runApp(const LanguageLearningApp()); // Ensure const is used if applicable
}

class LanguageLearningApp extends StatelessWidget {
  const LanguageLearningApp({super.key});

  @override
  Widget build(BuildContext context) {
    final lessonRepository = LessonRepository(
      firestoreService: LessonService(),
      localService: LocalLessonService(),
    );
    // printFirestoreSchema();
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: lessonRepository),
        RepositoryProvider(create: (context) => AuthService()),
        RepositoryProvider(create: (context) => LessonService()),
        RepositoryProvider(create: (context) => VocabularyService()),
        RepositoryProvider(create: (context) => TranslationService()),
        RepositoryProvider(create: (context) => LocalLessonService()),
      ],
      child: MultiBlocProvider(
        providers: [
          // 1. SETTINGS BLOC (Loaded immediately)
          BlocProvider(
            create: (context) => SettingsBloc()..add(LoadSettings()),
          ),
          // 2. AUTH BLOC
          BlocProvider(
            create: (context) =>
                AuthBloc(context.read<AuthService>())
                  ..add(AuthCheckRequested()),
          ),
          // 3. LESSON BLOC
          BlocProvider<LessonBloc>(
            create: (context) => LessonBloc(
              geminiService: GeminiService(), // Inject Gemini Service
              lessonRepository: lessonRepository, // Inject Repo, NOT services
            ),
          ),
          BlocProvider<QuizBloc>(create: (context) => QuizBloc()),
          // 4. VOCABULARY BLOC
          BlocProvider(
            create: (context) =>
                VocabularyBloc(context.read<VocabularyService>()),
          ),
        ],
        // Wrap MaterialApp with Settings Builder to apply themes
        child: BlocBuilder<SettingsBloc, SettingsState>(
          builder: (context, settings) {
            return MaterialApp(
              title: 'LinguaFlow',
              debugShowCheckedModeBanner: false,

              // --- THEME CONFIGURATION ---
              themeMode: settings.themeMode,

              // Light Theme
              theme: ThemeData(
                brightness: Brightness.light,
                primarySwatch: Colors.blue,
                scaffoldBackgroundColor: Colors.white,
                appBarTheme: AppBarTheme(
                  elevation: 0,
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                ),
                // Optional: Adjust font scale globally
                textTheme: TextTheme(
                  bodyMedium: TextStyle(fontSize: 14 * settings.fontSizeScale),
                  bodyLarge: TextStyle(fontSize: 16 * settings.fontSizeScale),
                ),
              ),

              // Dark Theme
              darkTheme: ThemeData(
                brightness: Brightness.dark,
                primarySwatch: Colors.blue,
                scaffoldBackgroundColor: Color(0xFF121212),
                appBarTheme: AppBarTheme(
                  elevation: 0,
                  backgroundColor: Color(0xFF121212),
                  foregroundColor: Colors.white,
                ),
                textTheme: TextTheme(
                  bodyMedium: TextStyle(fontSize: 14 * settings.fontSizeScale),
                  bodyLarge: TextStyle(fontSize: 16 * settings.fontSizeScale),
                ),
              ),

              home: AuthGate(),
            );
          },
        ),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is AuthAuthenticated) {
          return MainNavigationScreen();
        }
        return LoginScreen();
      },
    );
  }
}
