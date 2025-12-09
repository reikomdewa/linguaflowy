import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';

// Screens
import 'package:linguaflow/screens/home/home_screen.dart';
import 'package:linguaflow/screens/library/library_screen.dart';
import 'package:linguaflow/screens/profile/profile_screen.dart';
import 'package:linguaflow/screens/vocabulary/vocabulary_screen.dart';
import 'package:linguaflow/screens/admin/admin_dashboard_screen.dart';
import 'package:linguaflow/utils/constants.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  _MainNavigationScreenState createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  // Update with your real email(s)
  static const List<String> adminEmails = [
   
    "tester_email@gmail.com",
  ];

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;

    if (authState is! AuthAuthenticated) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final user = authState.user;
final bool isAdmin = AppConstants.isAdmin(user.email);

    // 1. Build the list of Screens dynamically
    final List<Widget> screens = [
      HomeScreen(),
      const LibraryScreen(),
      const VocabularyScreen(),
    ];

    // 2. Build the Navigation Items dynamically
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

    // --- ALWAYS: Add Profile Tab (at the end) ---
    screens.add(ProfileScreen());
    navItems.add(
      const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
    );

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed, // Needed for 4+ tabs
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels:
            true, // Good for 5 tabs so users know what they are
        items: navItems,
      ),
    );
  }
}
