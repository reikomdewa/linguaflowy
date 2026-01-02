// --- NEW WIDGET: App Download Button ---
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

Widget buildAppDownloadButton(bool isDark, context) {
  // The button should only be visible on Web and not in Desktop mode.
  if (kIsWeb) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      child: InkWell(
        onTap: () async {
          // Play Store URL
          final url = Uri.parse(
            'https://play.google.com/apps/testing/com.reikom.linguaflow',
          );
          if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Could not open Play Store link.")),
            );
          }
        },
        borderRadius: BorderRadius.circular(25.0), // Match the rounded corners
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1E1E1E)
                : Colors.white, // Match background theme
            borderRadius: BorderRadius.circular(25.0),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.grey.shade300,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min, // Use minimum space
            children: [
              // Add an icon if you have one (e.g., Google Play icon)
              // Icon(Icons.android, color: Colors.green), SizedBox(width: 8),
              Text(
                "Get the App on Google Play",
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 8),
              // Add an arrow or play store icon for visual cue
              Icon(
                Icons.arrow_outward,
                size: 18,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ],
          ),
        ),
      ),
    );
  }
  return const SizedBox.shrink(); // Don't show if not on web mobile
}
