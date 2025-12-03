// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:linguaflow/blocs/settings/settings_bloc.dart';
// import 'package:linguaflow/screens/main_navigation_screen.dart';
// import 'package:linguaflow/services/local_lesson_service.dart';
// import 'package:linguaflow/services/youtube_service.dart';
// import 'package:shared_preferences/shared_preferences.dart';

// // Import all screens and services
// import 'screens/auth/login_screen.dart';
// import 'screens/home/home_screen.dart';
// import 'screens/library/library_screen.dart';
// import 'screens/vocabulary/vocabulary_screen.dart';
// import 'screens/reader/reader_screen.dart';
// import 'services/auth_service.dart';
// import 'services/lesson_service.dart';
// import 'services/vocabulary_service.dart';
// import 'services/translation_service.dart';
// import 'blocs/auth/auth_bloc.dart';
// import 'blocs/lesson/lesson_bloc.dart';
// import 'blocs/vocabulary/vocabulary_bloc.dart';
// import 'package:logging/logging.dart';

// void main() async {
//   // Enable verbose logging from youtube_explode_dart
//   Logger.root.level = Level.ALL;
//   Logger.root.onRecord.listen((record) {
//     // You can customize this
//     print('[${record.level.name}] ${record.time}: ${record.message}');
//   });
//   WidgetsFlutterBinding.ensureInitialized();
//   await Firebase.initializeApp();
//   runApp(LanguageLearningApp());
// }

// class LanguageLearningApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MultiRepositoryProvider(
//       providers: [
//         RepositoryProvider(create: (context) => AuthService()),
//         RepositoryProvider(create: (context) => LessonService()),
//         RepositoryProvider(create: (context) => VocabularyService()),
//         RepositoryProvider(create: (context) => TranslationService()),
//         // RepositoryProvider(create: (context) => YouTubeService()),
//         RepositoryProvider(create: (context) => LocalLessonService()),
//          BlocProvider(create: (context) => SettingsBloc()..add(LoadSettings())),
//       ],
//       child: MultiBlocProvider(
//         providers: [
//           BlocProvider(
//             create: (context) =>
//                 AuthBloc(context.read<AuthService>())
//                   ..add(AuthCheckRequested()),
//           ),
//           BlocProvider(
//             create: (context) => LessonBloc(
//               context.read<LessonService>(),
//               context.read<LocalLessonService>(), // Use Local Service
//             ),
//           ),
         
//           BlocProvider(
//             create: (context) =>
//                 VocabularyBloc(context.read<VocabularyService>()),
//           ),
//         ],
      
//         child: MaterialApp(
         
//           home: AuthGate(),
//           debugShowCheckedModeBanner: false,
//         ),
//       ),
//     );
//   }
// }

// class AuthGate extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return BlocBuilder<AuthBloc, AuthState>(
//       builder: (context, state) {
//         if (state is AuthAuthenticated) {
//           return MainNavigationScreen();
//         }
//         return LoginScreen();
//       },
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:linguaflow/blocs/settings/settings_bloc.dart';
import 'package:linguaflow/screens/main_navigation_screen.dart';
import 'package:linguaflow/services/local_lesson_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Import all screens and services
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/library/library_screen.dart';
import 'screens/vocabulary/vocabulary_screen.dart';
import 'screens/reader/reader_screen.dart';
import 'services/auth_service.dart';
import 'services/lesson_service.dart';
import 'services/vocabulary_service.dart';
import 'services/translation_service.dart';
import 'blocs/auth/auth_bloc.dart';
import 'blocs/lesson/lesson_bloc.dart';
import 'blocs/vocabulary/vocabulary_bloc.dart';
import 'package:logging/logging.dart';

void main() async {
  // Enable verbose logging
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    print('[${record.level.name}] ${record.time}: ${record.message}');
  });
  
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  runApp(LanguageLearningApp());
}

class LanguageLearningApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
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
            create: (context) => AuthBloc(context.read<AuthService>())
              ..add(AuthCheckRequested()),
          ),
          // 3. LESSON BLOC
          BlocProvider(
            create: (context) => LessonBloc(
              context.read<LessonService>(),
              context.read<LocalLessonService>(),
            ),
          ),
          // 4. VOCABULARY BLOC
          BlocProvider(
            create: (context) => VocabularyBloc(context.read<VocabularyService>()),
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