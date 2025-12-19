import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// --- BLOCS ---
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/lesson/lesson_bloc.dart';
import 'package:linguaflow/blocs/quiz/quiz_bloc.dart';
import 'package:linguaflow/blocs/settings/settings_bloc.dart'; // Crucial for Themes
import 'package:linguaflow/blocs/speak/speak_bloc.dart';
import 'package:linguaflow/blocs/vocabulary/vocabulary_bloc.dart';

// --- SERVICES & REPOSITORIES ---
import 'package:linguaflow/services/auth_service.dart';
import 'package:linguaflow/services/speak/chat_service.dart';
import 'package:linguaflow/services/gemini_service.dart';
import 'package:linguaflow/services/lesson_service.dart'; // Firestore Service
import 'package:linguaflow/services/hybrid_lesson_service.dart'; // Local Service
import 'package:linguaflow/services/repositories/lesson_repository.dart';
import 'package:linguaflow/services/translation_service.dart';
import 'package:linguaflow/services/vocabulary_service.dart';
import 'package:media_kit/media_kit.dart';

// --- SCREENS ---
import 'package:linguaflow/screens/auth/login_screen.dart';
import 'package:linguaflow/screens/main_navigation_screen.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  // 1. Load Env & Init Gemini
  await dotenv.load(fileName: ".env");
  final apiKey = dotenv.env['GEMINI_API_KEY'];
  if (apiKey != null) {
    Gemini.init(apiKey: apiKey);
  }

  // 2. Init Firebase
  await Firebase.initializeApp();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  // 3. Init Audio Background
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.ryanheise.bg_demo.channel.audio',
    androidNotificationChannelName: 'Audio playback',
    androidNotificationOngoing: true,
    notificationColor: const Color(0xFF6A11CB),
    androidNotificationIcon: 'mipmap/ic_launcher',
  );

  runApp(const LinguaflowApp());
}

class LinguaflowApp extends StatelessWidget {
  const LinguaflowApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize Repository with both Firestore and Local data sources
    final lessonRepository = LessonRepository(
      firestoreService: LessonService(),
      localService: HybridLessonService(),
    );

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: lessonRepository),
        RepositoryProvider(create: (context) => AuthService()),
        RepositoryProvider(create: (context) => LessonService()),
        RepositoryProvider(create: (context) => VocabularyService()),
        RepositoryProvider(create: (context) => TranslationService()),
        RepositoryProvider(create: (context) => HybridLessonService()),
        RepositoryProvider(create: (context) => ChatService()),
      ],
      child: MultiBlocProvider(
        providers: [
          // 1. SETTINGS BLOC (Must load first for Theme)
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
              geminiService: GeminiService(),
              lessonRepository: lessonRepository,
            ),
          ),
          // 4. QUIZ BLOC
          BlocProvider<QuizBloc>(create: (context) => QuizBloc()),
          BlocProvider<SpeakBloc>(create: (context) => SpeakBloc()),
          // 5. VOCABULARY BLOC
          BlocProvider(
            create: (context) =>
                VocabularyBloc(context.read<VocabularyService>()),
          ),
        ],
        // Listen to SettingsBloc to change ThemeMode dynamically
        child: BlocBuilder<SettingsBloc, SettingsState>(
          builder: (context, settings) {
            const Color hyperBlue = Color(0xFF007AFF);
            const Color charcoal = Color(0xFF101010); // Threads dark background
            const Color lightGreyBorder = Color(0xFFE5E5E5);
            const Color darkGreyBorder = Color(0xFF262626);
            return MaterialApp(
              title: 'LinguaFlow',
              debugShowCheckedModeBanner: false,
              themeMode: settings.themeMode,

              // --- THREADS LIGHT THEME ---
              theme: ThemeData(
                useMaterial3: true,
                brightness: Brightness.light,
                primaryColor: Colors
                    .black, // Threads uses black as the primary action color
                scaffoldBackgroundColor: Colors.white,
                cardColor: const Color(0xFFF9F9F9), // Slightly off-white cards
                dividerColor: lightGreyBorder,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: hyperBlue,
                  brightness: Brightness.light,
                  primary: Colors.black, // Primary actions like buttons
                  secondary: hyperBlue,
                  surface: Colors.white,
                ),
                appBarTheme: const AppBarTheme(
                  elevation: 0,
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  centerTitle: true,
                  titleTextStyle: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800, // Thick "Threads" style title
                    color: Colors.black,
                  ),
                ),
                // Make chips and buttons more rounded
                chipTheme: ChipThemeData(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  side: const BorderSide(color: lightGreyBorder),
                  backgroundColor: Colors.white,
                ),
                elevatedButtonTheme: ElevatedButtonThemeData(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              // --- THREADS CHARCOAL DARK THEME ---
              darkTheme: ThemeData(
                useMaterial3: true,
                brightness: Brightness.dark,
                primaryColor: Colors.white,
                scaffoldBackgroundColor: charcoal, // Deep charcoal background
                cardColor: const Color(
                  0xFF181818,
                ), // Slightly lighter charcoal for cards
                dividerColor: darkGreyBorder,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: hyperBlue,
                  brightness: Brightness.dark,
                  primary: Colors.white,
                  secondary: hyperBlue,
                  surface: charcoal,
                ),
                appBarTheme: const AppBarTheme(
                  elevation: 0,
                  backgroundColor: charcoal,
                  foregroundColor: Colors.white,
                  centerTitle: true,
                  titleTextStyle: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                chipTheme: ChipThemeData(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  side: const BorderSide(color: darkGreyBorder),
                  backgroundColor: const Color(0xFF181818),
                ),
                elevatedButtonTheme: ElevatedButtonThemeData(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              home: const AuthGate(),
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
        // 1. User is Authenticated -> Remove Splash & Go Home
        if (state is AuthAuthenticated) {
          FlutterNativeSplash.remove();
          return MainNavigationScreen();
        }

        // 2. User is Logged Out -> Remove Splash & Show Login
        if (state is AuthUnauthenticated) {
          FlutterNativeSplash.remove();
          return LoginScreen();
        }

        // 3. Still Loading (AuthInitial)
        // The Native Splash is still "Preserved" and covering the screen.
        // So we can just return an empty container behind it.
        return const SizedBox.shrink();
      },
    );
  }
}
