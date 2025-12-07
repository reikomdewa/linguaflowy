import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/services/course_service.dart';

// --- IMPORT THE NEW WIDGETS ---
import 'widgets/learn_filters.dart';
import 'widgets/lesson_unit_card.dart';

class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key});

  @override
  _LearnScreenState createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  final CourseService _courseService = CourseService();

  // --- STATE ---
  String _selectedFilter = 'All';
  final List<String> _filters = [
    'All',
    'Stories',
    'News',
    'Bites',
    'Grammar tips',
  ];

  List<LessonModel> _lessons = [];
  bool _isLoading = true;

  // --- PROGRESS TRACKING ---
  final int _demoCompletedSteps = 2;
  int _expandedLessonIndex = 0;
  int _expandedStepIndex = 0;

  // --- LESSON STEPS CONFIGURATION ---
  // Keeping this here as it defines the structure of data for this screen
  final List<Map<String, dynamic>> _lessonSteps = [
    {
      'title': 'Vocabulary',
      'time': '5 min',
      'icon': Icons.copy_all_rounded,
      'color': const Color(0xFF26C6DA),
    },
    {
      'title': 'Pronunciation',
      'time': '3 min',
      'icon': Icons.mic_rounded,
      'color': const Color(0xFFFF7043),
    },
    {
      'title': 'Video Context',
      'time': '7 min',
      'icon': Icons.videocam_rounded,
      'color': const Color(0xFF9CCC65),
    },
    {
      'title': 'Grammar Rules',
      'time': '8 min',
      'icon': Icons.book_rounded,
      'color': const Color(0xFFEF5350),
    },
    {
      'title': 'AI Conversation',
      'time': '5 min',
      'icon': Icons.chat_bubble_rounded,
      'color': const Color(0xFF42A5F5),
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadContent();
    });
  }

  Future<void> _loadContent() async {
    setState(() => _isLoading = true);
    final authState = context.read<AuthBloc>().state;

    if (authState is AuthAuthenticated) {
      final lessons = await _courseService.getCourseLessons(
        languageCode: authState.user.currentLanguage,
        userLevel: authState.user.currentLevel,
        categoryFilter: _selectedFilter,
      );

      if (mounted) {
        setState(() {
          _lessons = lessons;
          _isLoading = false;
        });
      }
    }
  }

  void _handleFilterSelect(String filter) {
    setState(() => _selectedFilter = filter);
    _loadContent();
  }

  void _handleExpand(int lessonIndex, int stepIndex) {
    setState(() {
      _expandedLessonIndex = lessonIndex;
      _expandedStepIndex = stepIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Refactored Filter Bar
            LearnFilters(
              filters: _filters,
              selectedFilter: _selectedFilter,
              onSelect: _handleFilterSelect,
            ),

            // 2. Main Content Area
            if (_isLoading)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_lessons.isEmpty)
              _buildEmptyState()
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 100),
                  itemCount: _lessons.length,
                  itemBuilder: (context, index) {
                    return LessonUnitCard(
                      lessonIndex: index,
                      lesson: _lessons[index],
                      lessonSteps: _lessonSteps,
                      expandedLessonIndex: _expandedLessonIndex,
                      expandedStepIndex: _expandedStepIndex,
                      demoCompletedSteps: _demoCompletedSteps,
                      onExpand: _handleExpand,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.video_library_outlined, size: 60, color: Colors.grey),
          SizedBox(height: 16),
          Text("No content found.", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}