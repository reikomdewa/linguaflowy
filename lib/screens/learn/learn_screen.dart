import 'package:flutter/material.dart';

class LearnScreen extends StatefulWidget {
  @override
  _LearnScreenState createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  // --- STATE ---
  String _selectedFilter = 'Did you know...?';
  final List<String> _filters = [
    'Did you know...?',
    'Today\'s news',
    'Spaniards around',
    'Grammar tips'
  ];

  // --- DUMMY DATA FOR TIMELINE ---
  final List<LearnStep> _steps = [
    LearnStep(
      icon: Icons.copy_all_rounded, // Vocabulary icon
      color: Color(0xFF26C6DA), // Teal
      title: 'Vocabulary',
      subtitle: '5 minutes',
      status: StepStatus.active, // The current one
    ),
    LearnStep(
      icon: Icons.mic_rounded,
      color: Color(0xFFFF7043), // Orange
      title: 'Pronunciation',
      subtitle: '3 minutes',
      status: StepStatus.locked,
    ),
    LearnStep(
      icon: Icons.videocam_rounded,
      color: Color(0xFF9CCC65), // Light Green
      title: 'In Context',
      subtitle: '7 minutes',
      status: StepStatus.locked,
    ),
    LearnStep(
      icon: Icons.book_rounded,
      color: Color(0xFFEF5350), // Red
      title: 'As much/as many ... as I.',
      subtitle: '8 minutes',
      status: StepStatus.locked,
    ),
     LearnStep(
      icon: Icons.chat_bubble_rounded,
      color: Color(0xFF42A5F5), // Blue
      title: 'AI Conversation',
      subtitle: '5 minutes',
      status: StepStatus.locked,
    ),
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
                _buildHeader(isDark, textColor),
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.fromLTRB(20, 10, 20, 100),
                    itemCount: _steps.length,
                    itemBuilder: (context, index) {
                      return _buildTimelineItem(
                        context, 
                        _steps[index], 
                        index, 
                        _steps.length, 
                        isDark,
                        textColor
                      );
                    },
                  ),
                ),
              ],
            ),
            // The Floating Timer Pill (Bottom Left)
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
            icon: Icon(Icons.arrow_back),
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
                      onTap: () => setState(() => _selectedFilter = filter),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? Color(0xFF263238) // Dark Blue/Grey like screenshot
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          filter,
                          style: TextStyle(
                            color: isSelected 
                                ? Colors.white 
                                : Colors.grey,
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

  Widget _buildHeader(bool isDark, Color? textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24, height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  shape: BoxShape.circle,
                ),
                child: Text("1", style: TextStyle(color: Colors.white, fontSize: 12)),
              ),
              SizedBox(width: 8),
              Text(
                "Unit 1",
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            "Eruption",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(
    BuildContext context, 
    LearnStep step, 
    int index, 
    int total, 
    bool isDark,
    Color? textColor
  ) {
    final bool isLast = index == total - 1;
    final bool isActive = step.status == StepStatus.active;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LEFT SIDE: LINE + ICON
          Container(
            width: 50,
            child: Column(
              children: [
                // Top Line (connects to previous)
                // We use a custom painter or containers for lines
                // Circle
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: step.color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: step.color.withOpacity(0.4),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(step.icon, color: Colors.white, size: 24),
                ),
                // Bottom Line (connects to next)
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: isDark ? Colors.grey[800] : Colors.grey[300],
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: 16),
          
          // RIGHT SIDE: CONTENT
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 32.0), // Spacing between items
              child: isActive 
                  ? _buildActiveCard(step, isDark)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(height: 12), // Align text with circle center roughly
                        Text(
                          step.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          step.subtitle,
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveCard(LearnStep step, bool isDark) {
    // The active item has a dark background card in the screenshot
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Color(0xFF1E272E) : Color(0xFF263238), // Dark Blue/Grey
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  step.subtitle,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Start Lesson Logic
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 0,
            ),
            child: Text("Continue", style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingTimer() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Color(0xFFFFD54F), // The Yellow color from screenshot
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, color: Colors.black87, size: 20),
          SizedBox(width: 8),
          Text(
            "04:11",
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

// --- MODELS ---

enum StepStatus { active, locked, completed }

class LearnStep {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final StepStatus status;

  LearnStep({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.status,
  });
}