import 'package:flutter/material.dart';

class TabButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget? destinationScreen;
  final VoidCallback? onCustomTap;

  const TabButton({
    super.key,
    required this.title,
    this.icon = Icons.auto_awesome, // Default icon, can be overridden
    this.destinationScreen,
    this.onCustomTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // Preserve exact UI styling logic
    final List<Color> gradientColors = isDark
        ? [const Color(0xFFFFFFFF), const Color(0xFFE0E0E0)]
        : [const Color(0xFF2C3E50), const Color(0xFF000000)];
        
    final Color textColor = isDark ? Colors.black : Colors.white;
    
    final Color shadowColor = isDark
        ? Colors.white.withValues(alpha: 0.15)
        : Colors.black.withValues(alpha: 0.3);

    return Padding(
      padding: const EdgeInsets.only(left: 16.0, right: 16),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 12,
              offset: const Offset(0, 4),
              spreadRadius: 1,
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: () {
            // Priority 1: Custom logic (e.g., opening a dialog)
            if (onCustomTap != null) {
              onCustomTap!();
            } 
            // Priority 2: Navigate to the passed screen
            else if (destinationScreen != null) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => destinationScreen!),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: textColor, size: 20),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}