import 'package:flutter/material.dart';
import 'package:linguaflow/screens/people/people_screen.dart'; // Import your PeopleScreen
import 'package:linguaflow/screens/speak/widgets/views/live_explore_tab.dart'; // The refactored rooms view

class SpeakView extends StatefulWidget {
  const SpeakView({super.key});

  @override
  State<SpeakView> createState() => _SpeakViewState();
}

class _SpeakViewState extends State<SpeakView> {
  @override
  Widget build(BuildContext context) {
    // Colors
    final Color bgDark = const Color(0xFF15161A);
    // final Color primaryPink = const Color(0xFFE91E63);

    return DefaultTabController(
      length: 2,
      initialIndex: 1, // Defaults to "Live" tab (optional)
      child: Scaffold(
        backgroundColor: bgDark,
        appBar: AppBar(
          backgroundColor: bgDark,
          elevation: 0,
          toolbarHeight: 0, // Hides standard app bar title to save space
          bottom: TabBar(
            indicatorColor: Colors.transparent,
            dividerColor: Colors.transparent,
            // indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
            tabs: const [
              Tab(text: "Live"), // The People Screen
              Tab(text: "People"), // The Rooms/Tutors Screen
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            // Left Tab
            LiveExploreTab(),
            PeopleScreen(), // Right Tab (The logic moved below)
          ],
        ),
      ),
    );
  }
}
