
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:linguaflow/screens/main_navigation_screen.dart';
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

void main() async {
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
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => AuthBloc(context.read<AuthService>())
              ..add(AuthCheckRequested()),
          ),
          BlocProvider(
            create: (context) => LessonBloc(context.read<LessonService>()),
          ),
          BlocProvider(
            create: (context) => VocabularyBloc(context.read<VocabularyService>()),
          ),
        ],
        child: MaterialApp(
          title: 'Language Learning',
          theme: ThemeData(
            primarySwatch: Colors.blue,
            brightness: Brightness.light,
            scaffoldBackgroundColor: Colors.white,
            appBarTheme: AppBarTheme(
              elevation: 0,
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
            ),
          ),
          darkTheme: ThemeData(
            primarySwatch: Colors.blue,
            brightness: Brightness.dark,
          ),
          home: AuthGate(),
          debugShowCheckedModeBanner: false,
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
