import 'package:flutter/foundation.dart'; // REQUIRED for kIsWeb
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

// MODELS
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/blocs/lesson/lesson_bloc.dart';

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

    // 1. Try Bloc Memory first
    final lessonState = context.read<LessonBloc>().state;
    if (lessonState is LessonLoaded) {
      try {
        final found = lessonState.lessons.firstWhere((l) => l.id == widget.lessonId);
        setState(() {
          _lesson = found;
          _isLoading = false;
        });
        return;
      } catch (_) {}
    }

    // 2. Fetch from Firestore if not in memory (Deep Link)
    try {
      final doc = await FirebaseFirestore.instance
          .collection('lessons')
          .doc(widget.lessonId)
          .get();

      if (doc.exists && doc.data() != null) {
        final fetchedLesson = LessonModel.fromMap(doc.data()!, doc.id);
        if (mounted) {
          setState(() {
            _lesson = fetchedLesson;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() { _error = "Lesson not found"; _isLoading = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(_error ?? "Lesson not found"),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/'),
                child: const Text("Go Home"),
              )
            ],
          ),
        ),
      );
    }

    // 3. SUCCESS - DECIDE WHICH SCREEN TO SHOW
    // This is where we handle the logic you asked for:
    if (kIsWeb) {
      return ReaderScreenWeb(lesson: _lesson!);
    } else {
      return ReaderScreen(lesson: _lesson!);
    }
  }
}