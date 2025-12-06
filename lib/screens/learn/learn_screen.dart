import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/services/course_service.dart';
import 'package:linguaflow/screens/learn/active_lesson_screen.dart';

class LearnScreen extends StatefulWidget {
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
  // _maxReachedStep: The furthest step the user has actually finished (0-4).
  // _expandedStepIndex: The specific card currently open on screen.
  int _maxReachedStep = 0; 
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
          // Reset progress for demo purposes when filter changes
          _maxReachedStep = 0; 
          _expandedStepIndex = 0;
        });
      }
    }
  }

  // --- LESSON STEPS CONFIGURATION ---
  final List<Map<String, dynamic>> _lessonSteps = [
    {'title': 'Vocabulary', 'time': '5 minutes', 'icon': Icons.copy_all_rounded, 'color': Color(0xFF26C6DA)},
    {'title': 'Pronunciation', 'time': '3 minutes', 'icon': Icons.mic_rounded, 'color': Color(0xFFFF7043)},
    {'title': 'Video Context', 'time': '7 minutes', 'icon': Icons.videocam_rounded, 'color': Color(0xFF9CCC65)},
    {'title': 'Grammar Rules', 'time': '8 minutes', 'icon': Icons.book_rounded, 'color': Color(0xFFEF5350)},
    {'title': 'AI Conversation', 'time': '5 minutes', 'icon': Icons.chat_bubble_rounded, 'color': Color(0xFF42A5F5)},
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

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
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. HEADER (Unit & Title)
                          _buildHeader(isDark, textColor, _lessons[0]),

                          // 2. TIMELINE (Steps)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _lessonSteps.length,
                              itemBuilder: (context, index) {
                                return _buildTimelineItem(
                                  context, 
                                  index, 
                                  isDark, 
                                  textColor,
                                  _lessons[0] // Pass current lesson data
                                );
                              },
                            ),
                          ),

                          // 3. NEXT LESSON TEASER
                          if (_lessons.length > 1)
                            _buildNextLessonTeaser(isDark, textColor, _lessons[1]),
                        ],
                      ),
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

  Widget _buildHeader(bool isDark, Color? textColor, LessonModel lesson) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24, height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.grey[800], shape: BoxShape.circle),
                child: const Text("1", style: TextStyle(color: Colors.white, fontSize: 12)),
              ),
              const SizedBox(width: 8),
              const Text("Unit 1", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            lesson.title,
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textColor),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(BuildContext context, int index, bool isDark, Color? textColor, LessonModel lesson) {
    final stepData = _lessonSteps[index];
    final bool isLast = index == _lessonSteps.length - 1;
    
    // --- STATE LOGIC ---
    // Expanded: The card currently showing details
    bool isExpanded = index == _expandedStepIndex;
    
    // Completed: Steps strictly BEFORE our current max progress
    bool isCompleted = index < _maxReachedStep;
    
    // "Future": Steps AFTER our current max progress
    // Visually Grey, but still clickable
    bool isFutureStep = index > _maxReachedStep;

    // --- COLOR LOGIC ---
    Color iconBgColor;
    if (isFutureStep) {
      iconBgColor = Colors.grey[800]!; // Grey out future steps
    } else {
      iconBgColor = stepData['color']; // Active or Completed get color
    }

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
                  // ALLOW CLICKING ANY STEP
                  onTap: () {
                    setState(() {
                      _expandedStepIndex = index;
                    });
                  },
                  child: Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: iconBgColor,
                      shape: BoxShape.circle,
                      boxShadow: isFutureStep ? [] : [
                        // Only show shadow for active/completed
                        BoxShadow(color: stepData['color'].withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))
                      ],
                    ),
                    child: Icon(
                      // Show Checkmark ONLY if completed AND not currently open
                      (isCompleted && !isExpanded) ? Icons.check : stepData['icon'], 
                      color: Colors.white, 
                      size: 24
                    ),
                  ),
                ),
                // Line
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2, 
                      color: isCompleted 
                          ? stepData['color'] // Colored line if segment passed
                          : (isDark ? Colors.grey[800] : Colors.grey[300]),
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
                  ? _buildActiveCard(stepData, isDark, index, lesson) // Show Card if expanded
                  : GestureDetector(
                      // Allow tapping text to expand too
                      onTap: () {
                        setState(() {
                          _expandedStepIndex = index;
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
                              // Grey text for future steps, Normal color for reached steps
                              color: isFutureStep ? Colors.grey : textColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Subtitle Logic
                          if (isCompleted) 
                            const Text("Completed", style: TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.bold))
                          else 
                            Text(stepData['time'], style: const TextStyle(color: Colors.grey, fontSize: 13)),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveCard(Map<String, dynamic> stepData, bool isDark, int stepIndex, LessonModel lesson) {
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
              // Open Lesson at specific step
              await Navigator.push(
                context, 
                MaterialPageRoute(
                  builder: (_) => ActiveLessonScreen(
                    lesson: lesson,
                    initialStep: stepIndex, 
                  )
                )
              );
              
              // SIMULATED PROGRESS LOGIC
              // When they return from a step, check if we should unlock the next
              setState(() {
                if (stepIndex == _maxReachedStep && _maxReachedStep < _lessonSteps.length - 1) {
                  _maxReachedStep++;
                  _expandedStepIndex = _maxReachedStep; // Auto-expand next step
                }
              });
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

  Widget _buildNextLessonTeaser(bool isDark, Color? textColor, LessonModel nextLesson) {
    return Container(
      margin: const EdgeInsets.only(top: 10, left: 20, right: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           SizedBox(
            width: 50,
            child: Column(
              children: [
                Container(
                  width: 2, height: 30,
                  color: isDark ? Colors.grey[800] : Colors.grey[300],
                ),
                Container(
                  width: 48, height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey, width: 2)
                  ),
                  child: const Text("2", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Opacity(
                opacity: 0.6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("NEXT UP", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text(
                      nextLesson.title,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${nextLesson.type.toUpperCase()} • Beginner",
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          )
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