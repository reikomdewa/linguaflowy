import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/utils/constants.dart';

// Screens
import 'package:linguaflow/screens/home/home_screen.dart';
import 'package:linguaflow/screens/search/search_screen.dart';
import 'package:linguaflow/screens/library/library_screen.dart';
import 'package:linguaflow/screens/profile/profile_screen.dart';
import 'package:linguaflow/screens/vocabulary/vocabulary_screen.dart';
import 'package:linguaflow/screens/admin/admin_dashboard_screen.dart';

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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Modern Theme Colors
    final navBarColor = isDark ? const Color(0xFF000000) : Colors.white; 
    final selectedColor = isDark ? Colors.white : Colors.blueAccent; 
    final unselectedColor = isDark ? Colors.grey[600] : Colors.grey[500];

    // 1. Build the list of Screens
    // ORDER: Home -> Library -> Vocabulary -> Discover -> [Admin] -> Profile
    final List<Widget> screens = [
      HomeScreen(),
      const LibraryScreen(),
      const VocabularyScreen(),
      const SearchScreen(), 
    ];

    // 2. Build the Navigation Items
    final List<BottomNavigationBarItem> navItems = [
      const BottomNavigationBarItem(
        icon: Icon(Icons.home_filled), 
        label: 'Home'
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.library_books_rounded), 
        label: 'Library',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.school_rounded),
        label: 'Vocabulary',
      ),
      // --- FIXED DISCOVER TAB ---
      // I wrapped the icon in a Padding with `bottom: 4` 
      // This creates a gap that pushes the "Discover" text down to align with the others.
      const BottomNavigationBarItem(
        icon: Padding(
          padding: EdgeInsets.only(bottom: 4.0), 
          child: FaIcon(FontAwesomeIcons.magnifyingGlass, size: 20),
        ),
        label: 'Discover',
      ),
    ];

    // --- IF ADMIN: Add Admin Tab ---
    if (isAdmin) {
      screens.add(const AdminDashboardScreen());
      navItems.add(
        const BottomNavigationBarItem(
          icon: Icon(Icons.admin_panel_settings_rounded),
          label: 'Admin',
        ),
      );
    }

    // --- ALWAYS: Add Profile Tab ---
    screens.add(ProfileScreen());
    navItems.add(
      const BottomNavigationBarItem(
        icon: Icon(Icons.person_rounded), 
        label: 'Profile'
      ),
    );

    return ActiveTabNotifier(
      activeIndex: _currentIndex,
      child: Scaffold(
        body: IndexedStack(index: _currentIndex, children: screens),
        
        bottomNavigationBar: Theme(
          data: Theme.of(context).copyWith(
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: navBarColor,
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.white10 : Colors.black12, 
                  width: 0.5
                ),
              ),
            ),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) => setState(() => _currentIndex = index),
              
              type: BottomNavigationBarType.fixed,
              backgroundColor: navBarColor,
              selectedItemColor: selectedColor,
              unselectedItemColor: unselectedColor,
              
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
              
              elevation: 0, 
              showUnselectedLabels: true,
              items: navItems,
            ),
          ),
        ),
      ),
    );
  }
}