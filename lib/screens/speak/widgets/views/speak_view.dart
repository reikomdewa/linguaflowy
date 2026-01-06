import 'package:flutter/material.dart';
import 'package:linguaflow/screens/people/people_screen.dart';
import 'package:linguaflow/screens/speak/widgets/views/live_explore_tab.dart';

class SpeakView extends StatefulWidget {
  const SpeakView({super.key});

  @override
  State<SpeakView> createState() => _SpeakViewState();
}

class _SpeakViewState extends State<SpeakView> {
  @override
  Widget build(BuildContext context) {
    // Access the current theme data
    final theme = Theme.of(context);
    final scaffoldBg = theme.scaffoldBackgroundColor;

    // Use onSurface (Black in Light, White in Dark) for active text
    final activeColor = theme.colorScheme.onSurface;
    // Use hintColor (Grey) for inactive text
    final inactiveColor = theme.hintColor;

    return DefaultTabController(
      length: 2,
      initialIndex: 0, // Defaults to "Live" (Index 0)
      child: Scaffold(
        backgroundColor: scaffoldBg,
        appBar: AppBar(
          backgroundColor: scaffoldBg,
          elevation: 0,
          toolbarHeight: 0, // Hides standard app bar title area
          bottom: TabBar(
            indicatorColor: Colors.transparent,
            dividerColor: Colors.transparent,

            // Theme Aware Colors
            labelColor: activeColor,
            unselectedLabelColor: inactiveColor,

            // Text Styles
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w800, // Extra bold for active
              fontSize: 22, // Larger header-like size
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),

            tabs: const [
              Tab(text: "Live"),
              Tab(text: "People"),
            ],
          ),
        ),
        body: const TabBarView(children: [LiveExploreTab(), PeopleScreen()]),
      ),
    );
  }
}
