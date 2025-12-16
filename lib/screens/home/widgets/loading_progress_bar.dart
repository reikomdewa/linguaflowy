import 'package:flutter/material.dart';

class RealisticProgressBar extends StatefulWidget {
  final double width;
  const RealisticProgressBar({super.key, required this.width});

  @override
  State<RealisticProgressBar> createState() => _RealisticProgressBarState();
}

class _RealisticProgressBarState extends State<RealisticProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _startSimulation();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _startSimulation() async {
    // 1. Helper to animate safely
    Future<void> animateTo(double target, int ms, Curve curve) async {
      if (!mounted) return;
      await _controller.animateTo(
        target,
        duration: Duration(milliseconds: ms),
        curve: curve,
      );
    }

    // 2. Helper to pause safely
    Future<void> pause(int ms) async {
      if (!mounted) return;
      await Future.delayed(Duration(milliseconds: ms));
    }

    // --- LOGIC: The "Human" Loading Sequence ---
    
    // 0 -> 20%: Immediate response (connection)
    await animateTo(0.20, 300, Curves.easeOut);
    await pause(100); 

    // 20 -> 30%: Authentication / Handshake (pause)
    await animateTo(0.30, 800, Curves.linear); 
    await pause(400); 

    // 30 -> 60%: Bulk Download (fast burst)
    await animateTo(0.60, 500, Curves.easeInOut);
    await pause(200); 

    // 60 -> 80%: Parsing/Processing (slowing down)
    await animateTo(0.80, 1000, Curves.easeOut);
    await pause(500); 

    // 80 -> 90%: Finishing up (slow crawl)
    await animateTo(0.90, 1500, Curves.linear);
    await pause(500); 

    // 90 -> 91%: The "Just a sec..." hang
    await animateTo(0.91, 500, Curves.linear);
    await pause(1500);

    // 91 -> 98%: Zeno's Paradox (Never hits 100% until API returns)
    if (mounted) {
      await _controller.animateTo(
        0.98, 
        duration: const Duration(seconds: 15), 
        curve: Curves.decelerate,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // COLOR LOGIC:
    // Track: Use transparency so it looks good on any dark background
    final Color trackColor = isDark 
        ? Colors.white24       // Visible on dark backgrounds
        : Colors.black12;      // Visible on light backgrounds
    
    // Fill: Use the main scheme primary color
    final Color progressColor = theme.colorScheme.primary;

    // Text: Use standard body text color
    final Color textColor = theme.textTheme.bodyMedium?.color ?? 
        (isDark ? Colors.white70 : Colors.black87);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final percent = (_controller.value * 100).toInt();
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Container for shadowing/glow (optional, adds depth)
            Container(
              width: widget.width,
              height: 10,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                // Optional: subtle shadow in dark mode to pop from background
                boxShadow: isDark ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ] : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: _controller.value,
                  backgroundColor: trackColor,
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  minHeight: 10,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Loading lessons... $percent%",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: textColor.withOpacity(0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      },
    );
  }
}