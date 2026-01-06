import 'package:flutter/foundation.dart'; // REQUIRED for kIsWeb
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

// MODELS
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/blocs/lesson/lesson_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart'; // Import AuthBloc
import 'package:linguaflow/blocs/auth/auth_state.dart';

// SCREENS
import 'package:linguaflow/screens/reader/reader_screen.dart'; // Mobile
import 'package:linguaflow/screens/reader/reader_screen_web.dart'; // Web

class ReaderScreenWrapper extends StatefulWidget {
  final String lessonId;
  final LessonModel? initialLesson;

  const ReaderScreenWrapper({
    super.key,
    required this.lessonId,
    this.initialLesson,
  });

  @override
  State<ReaderScreenWrapper> createState() => _ReaderScreenWrapperState();
}

class _ReaderScreenWrapperState extends State<ReaderScreenWrapper> {
  LessonModel? _lesson;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialLesson != null) {
      _lesson = widget.initialLesson;
    } else {
      _findOrFetchLesson();
    }
  }

  Future<void> _findOrFetchLesson() async {
    setState(() => _isLoading = true);

    // 1. Try Bloc Memory first (Fastest)
    final lessonState = context.read<LessonBloc>().state;
    if (lessonState is LessonLoaded) {
      try {
        final found = lessonState.lessons.firstWhere((l) => l.id == widget.lessonId);
        setState(() {
          _lesson = found;
          _isLoading = false;
        });
        return;
      } catch (_) {
        // Not found in memory, continue to fetch
      }
    }

    try {
      DocumentSnapshot? doc;

      // 2. Try Global 'lessons' collection
      final globalRef = FirebaseFirestore.instance.collection('lessons').doc(widget.lessonId);
      final globalDoc = await globalRef.get();

      if (globalDoc.exists) {
        doc = globalDoc;
      } else {
        // 3. Try User's Private 'lessons' collection (Fallback for user-generated/YouTube)
        final authState = context.read<AuthBloc>().state;
        if (authState is AuthAuthenticated) {
          final userRef = FirebaseFirestore.instance
              .collection('users')
              .doc(authState.user.id)
              .collection('lessons') // Or 'library', depending on your DB structure
              .doc(widget.lessonId);
          
          final userDoc = await userRef.get();
          if (userDoc.exists) {
            doc = userDoc;
          }
        }
      }

      // 4. Process Result
      if (doc != null && doc.exists && doc.data() != null) {
        final fetchedLesson = LessonModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        if (mounted) {
          setState(() {
            _lesson = fetchedLesson;
            _isLoading = false;
          });
        }
      } else {
        debugPrint("❌ Lesson ID ${widget.lessonId} not found in Global or User DB.");
        if (mounted) setState(() { _error = "Lesson not found"; _isLoading = false; });
      }
    } catch (e) {
      debugPrint("❌ Error fetching lesson: $e");
      if (mounted) setState(() { _error = "Error loading lesson"; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Loading State
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 2. Error State
    if (_error != null || _lesson == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.broken_image_outlined, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  _error ?? "Lesson could not be loaded.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    // Use replace to avoid stacking error pages
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/');
                    }
                  },
                  child: const Text("Go Back"),
                )
              ],
            ),
          ),
        ),
      );
    }

    // 3. SUCCESS
    if (kIsWeb) {
      return ReaderScreenWeb(lesson: _lesson!);
    } else {
      return ReaderScreen(lesson: _lesson!);
    }
  }
}