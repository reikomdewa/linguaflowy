import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart'; // Ensure this is imported (comes with flutter_bloc)
import 'package:linguaflow/blocs/auth/auth_bloc.dart';

// Screens
import 'package:linguaflow/screens/home/home_screen.dart';
import 'package:linguaflow/screens/library/library_screen.dart';
import 'package:linguaflow/screens/profile/profile_screen.dart';
import 'package:linguaflow/screens/vocabulary/vocabulary_screen.dart';
import 'package:linguaflow/screens/admin/admin_dashboard_screen.dart';
import 'package:linguaflow/utils/constants.dart';

// --- VISIBILITY CONTROLLER ---
// We use this to broadcast the active tab index to deep widgets like the video player
class ActiveTabNotifier extends InheritedWidget {
  final int activeIndex;

  const ActiveTabNotifier({
    super.key,
    required this.activeIndex,
    required super.child,
  });

  static int? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<ActiveTabNotifier>()
        ?.activeIndex;
  }

  @override
  bool updateShouldNotify(ActiveTabNotifier oldWidget) {
    return oldWidget.activeIndex != activeIndex;
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  _MainNavigationScreenState createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;

    if (authState is! AuthAuthenticated) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final user = authState.user;
    final bool isAdmin = AppConstants.isAdmin(user.email);

    // 1. Build the list of Screens
    final List<Widget> screens = [
      HomeScreen(),
      const LibraryScreen(),
      const VocabularyScreen(), // Index 2
    ];

    // 2. Build the Navigation Items
    final List<BottomNavigationBarItem> navItems = [
      const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
      const BottomNavigationBarItem(
        icon: Icon(Icons.library_books),
        label: 'Library',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.book),
        label: 'Vocabulary',
      ),
    ];

    // --- IF ADMIN: Add Admin Tab ---
    if (isAdmin) {
      screens.add(const AdminDashboardScreen());
      navItems.add(
        const BottomNavigationBarItem(
          icon: Icon(Icons.admin_panel_settings),
          label: 'Admin',
        ),
      );
    }

    // --- ALWAYS: Add Profile Tab ---
    screens.add(ProfileScreen());
    navItems.add(
      const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
    );

    return ActiveTabNotifier(
      activeIndex: _currentIndex,
      child: Scaffold(
        // IndexedStack keeps state (video playing), so we need the Notifier to tell it to stop
        body: IndexedStack(index: _currentIndex, children: screens),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.blue,
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
          items: navItems,
        ),
      ),
    );
  }
}