import 'package:flutter/material.dart';
import 'package:linguaflow/screens/login/login_screen.dart';

class WebLoginLayout extends StatelessWidget {
  const WebLoginLayout({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Get Theme Data
    final theme = Theme.of(context);
    final hyperBlue = theme.colorScheme.secondary;
    final borderColor = theme.dividerColor;
    final surfaceColor = theme.cardColor;
    final screenHeight = MediaQuery.of(context).size.height;

    return Material(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Breakpoint
          final isNarrow = constraints.maxWidth < 900;

          if (isNarrow) {
            // -----------------------------------------------------------
            // MOBILE / TABLET WEB LAYOUT
            // -----------------------------------------------------------
            return SingleChildScrollView(
              child: Column(
                children: [
                  // SECTION 1: Login Form
                  // We give this a minimum height of the full screen (or 700px).
                  // This prevents the "Infinite Size" crash while making it look full-screen.
                  Container(
                    constraints: BoxConstraints(
                      // Ensure it's at least as tall as the screen,
                      // but enforce a minimum of 650px so the form isn't squashed on small landscape phones.
                      minHeight: screenHeight > 650 ? screenHeight : 650,
                    ),
                    // LoginFormContent uses Center(), so it will center itself within this massive box
                    child: const LoginFormContent(),
                  ),

                  // SECTION 2: Marketing Info (Below the fold)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 60,
                    ),
                    // Optional: Slight background color difference to separate sections?
                    // color: theme.colorScheme.surfaceContainerLow,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 500),
                        child: _buildMarketingPanel(
                          context,
                          theme,
                          hyperBlue,
                          isCentered: true,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          } else {
            // -----------------------------------------------------------
            // DESKTOP WEB LAYOUT
            // -----------------------------------------------------------
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Left Side: Login Form
                Expanded(
                  flex: 4,
                  child: _buildLoginPanel(surfaceColor, borderColor),
                ),

                const SizedBox(width: 80),

                // Right Side: Marketing Info
                Expanded(
                  flex: 6,
                  child: _buildMarketingPanel(context, theme, hyperBlue),
                ),
              ],
            );
          }
        },
      ),
    );
  }

  // --- REUSABLE WIDGETS ---

  Widget _buildLoginPanel(Color surfaceColor, Color borderColor) {
    return Container(
      padding: const EdgeInsets.all(40.0),
      decoration: BoxDecoration(
        // color: surfaceColor,
        // border: Border.all(color: borderColor, width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const LoginFormContent(),
    );
  }

  Widget _buildMarketingPanel(
    BuildContext context,
    ThemeData theme,
    Color hyperBlue, {
    bool isCentered = false,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: isCentered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          "🌊 LinguaFlow",
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: theme.primaryColor,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          "Don't study a language.\nAbsorb it.",
          textAlign: isCentered ? TextAlign.center : TextAlign.left,
          style: theme.textTheme.displayMedium?.copyWith(
            fontWeight: FontWeight.w900,
            height: 1.1,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          "Experience natural immersion just like you learned your first language. No boring drills—just flow.",
          textAlign: isCentered ? TextAlign.center : TextAlign.left,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontSize: 18,
            height: 1.5,
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 40),
        _buildFeatureRow(
          context,
          Icons.video_library_rounded,
          "Import Your Content",
          "Learn from Netflix, YouTube, or your favorite books.",
          hyperBlue,
        ),
        _buildFeatureRow(
          context,
          Icons.touch_app_rounded,
          "Instant Definitions",
          "Tap any word for meaning without breaking your flow.",
          hyperBlue,
        ),
        _buildFeatureRow(
          context,
          Icons.public,
          "80+ African Languages",
          "Plus 27 major global languages. Representation matters.",
          hyperBlue,
        ),
        _buildFeatureRow(
          context,
          Icons.psychology_rounded,
          "Smart Flashcards",
          "Intelligent review system that adapts to your memory.",
          hyperBlue,
        ),
      ],
    );
  }

  Widget _buildFeatureRow(
    BuildContext context,
    IconData icon,
    String title,
    String subTitle,
    Color iconColor,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subTitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
