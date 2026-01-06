import 'package:flutter/material.dart';

class LoadingView extends StatelessWidget {
  final String tip;
  final String title;
  final String subtitle;

  const LoadingView({
    super.key,
    required this.tip,
    this.title = "Loading...",
    this.subtitle = "This usually takes a few seconds",
  });

  @override
  Widget build(BuildContext context) {
    // Theme awareness
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final subTextColor = isDark ? Colors.white54 : Colors.grey[500];

    return Scaffold(
      // Scaffold ensures it has a background color matching the theme
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // You can uncomment the indicator if you want both
              // const CircularProgressIndicator(), 
              // const SizedBox(height: 24),
              
              Text(
                title,
                style: TextStyle(
                  fontSize: 24, 
                  fontWeight: FontWeight.w600,
                  color: textColor
                ),
              ),
              const SizedBox(height: 24),
              
              // The Tip
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.grey.shade200
                  )
                ),
                child: Column(
                  children: [
                    Icon(Icons.lightbulb_outline, color: Colors.amber, size: 28),
                    const SizedBox(height: 8),
                    Text(
                      tip,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18, 
                        fontWeight: FontWeight.w500,
                        color: textColor,
                        height: 1.3
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              Text(
                subtitle,
                style: TextStyle(color: subTextColor, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}