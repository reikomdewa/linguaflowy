import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/services/course_service.dart';
import 'package:linguaflow/screens/learn/active_lesson_screen.dart';
// Ensure you import the ReaderScreen
import 'package:linguaflow/screens/reader/reader_screen.dart'; 

class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key});

  @override
  _LearnScreenState createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  final CourseService _courseService = CourseService();

  // --- STATE ---
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Stories', 'News', 'Bites', 'Grammar tips'];

  List<LessonModel> _lessons = [];
  bool _isLoading = true;
  
  // --- PROGRESS TRACKING ---
  // For demo purposes, we will simulate that the first 2 steps of the 
  // first lesson are "Completed" to show the checkmark logic.
  final int _demoCompletedSteps = 2; 

  // To track which specific card (LessonIndex + StepIndex) is expanded
  int _expandedLessonIndex = 0;
  int _expandedStepIndex = 0;

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

  // --- LESSON STEPS CONFIGURATION ---
  final List<Map<String, dynamic>> _lessonSteps = [
    {'title': 'Vocabulary', 'time': '5 min', 'icon': Icons.copy_all_rounded, 'color': Color(0xFF26C6DA)},
    {'title': 'Pronunciation', 'time': '3 min', 'icon': Icons.mic_rounded, 'color': Color(0xFFFF7043)},
    {'title': 'Video Context', 'time': '7 min', 'icon': Icons.videocam_rounded, 'color': Color(0xFF9CCC65)},
    {'title': 'Grammar Rules', 'time': '8 min', 'icon': Icons.book_rounded, 'color': Color(0xFFEF5350)},
    {'title': 'AI Conversation', 'time': '5 min', 'icon': Icons.chat_bubble_rounded, 'color': Color(0xFF42A5F5)},
  ];

  @override
  Widget build(BuildContext context) {
    // Theme helpers
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopBar(context),
                
                if (_isLoading)
                  const Expanded(child: Center(child: CircularProgressIndicator()))
                else if (_lessons.isEmpty)
                  _buildEmptyState()
                else
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 100),
                      itemCount: _lessons.length,
                      itemBuilder: (context, index) {
                        return _buildFullLessonGroup(index);
                      },
                    ),
                  ),
              ],
            ),
            
            // Floating Timer Pill
            Positioned(
              left: 20,
              bottom: 30,
              child: _buildFloatingTimer(),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filters.map((filter) {
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: InkWell(
                      onTap: () {
                        setState(() => _selectedFilter = filter);
                        _loadContent();
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF263238) : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          filter,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Renders a complete Lesson (Header + Timeline Steps)
  Widget _buildFullLessonGroup(int lessonIndex) {
    final lesson = _lessons[lessonIndex];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Header (Unit X - Title)
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 24, height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: Colors.grey[800], shape: BoxShape.circle),
                    child: Text("${lessonIndex + 1}", style: const TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Unit ${lessonIndex + 1} • ${lesson.type}", 
                    style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 14)
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                lesson.title,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),

        // 2. The Timeline Steps for this Lesson
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _lessonSteps.length,
            itemBuilder: (context, stepIndex) {
              return _buildTimelineItem(
                context, 
                lessonIndex,
                stepIndex, 
                isDark, 
                textColor,
                lesson
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineItem(
    BuildContext context, 
    int lessonIndex,
    int stepIndex, 
    bool isDark, 
    Color? textColor, 
    LessonModel lesson
  ) {
    final stepData = _lessonSteps[stepIndex];
    final bool isLastStep = stepIndex == _lessonSteps.length - 1;
    
    // --- STATE LOGIC ---
    // Is this specific card expanded?
    bool isExpanded = (lessonIndex == _expandedLessonIndex && stepIndex == _expandedStepIndex);
    
    // Is Completed? (Simulated: First 2 steps of Lesson 0 are done)
    bool isCompleted = (lessonIndex == 0 && stepIndex < _demoCompletedSteps);

    // --- COLOR LOGIC (Always Colorful) ---
    Color baseColor = stepData['color']; 

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LEFT SIDE: Line + Icon
          SizedBox(
            width: 50,
            child: Column(
              children: [
                // Clickable Icon
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _expandedLessonIndex = lessonIndex;
                      _expandedStepIndex = stepIndex;
                    });
                  },
                  child: Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: baseColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: baseColor.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))
                      ],
                    ),
                    child: Icon(stepData['icon'], color: Colors.white, size: 24),
                  ),
                ),
                // Vertical Line
                if (!isLastStep)
                  Expanded(
                    child: Container(
                      width: 2, 
                      color: baseColor.withOpacity(0.3),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          
          // RIGHT SIDE: Card or Text
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 32.0),
              child: isExpanded 
                  ? _buildActiveCard(stepData, isDark, lessonIndex, stepIndex, lesson) 
                  : GestureDetector(
                      onTap: () {
                        setState(() {
                          _expandedLessonIndex = lessonIndex;
                          _expandedStepIndex = stepIndex;
                        });
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 12),
                          Text(
                            stepData['title'],
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          
                          // SUBTITLE: Time + Checkmark (if completed)
                          Row(
                            children: [
                              Text(stepData['time'], style: const TextStyle(color: Colors.grey, fontSize: 13)),
                              
                              if (isCompleted) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle
                                  ),
                                  child: const Icon(Icons.check, size: 10, color: Colors.white),
                                )
                              ]
                            ],
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveCard(
    Map<String, dynamic> stepData, 
    bool isDark, 
    int lessonIndex,
    int stepIndex, 
    LessonModel lesson
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E272E) : const Color(0xFF263238),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          const BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stepData['title'],
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  stepData['time'],
                  style: TextStyle(color: Colors.grey[400], fontSize: 13),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              // --- UPDATED NAVIGATION LOGIC ---
              if (stepData['title'] == 'Video Context') {
                // Navigate to ReaderScreen for the Video module
                await Navigator.push(
                  context, 
                  MaterialPageRoute(
                    builder: (_) => ReaderScreen(lesson: lesson)
                  )
                );
              } else {
                // Navigate to ActiveLessonScreen for other modules
                await Navigator.push(
                  context, 
                  MaterialPageRoute(
                    builder: (_) => ActiveLessonScreen(
                      lesson: lesson,
                      initialStep: stepIndex, 
                    )
                  )
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 0,
            ),
            child: const Text("Start", style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingTimer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD54F),
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, color: Colors.black87, size: 20),
          const SizedBox(width: 8),
          const Text("04:11", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
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