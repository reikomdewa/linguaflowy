import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_state.dart';
import 'package:linguaflow/constants/constants.dart';
import 'package:linguaflow/models/user_model.dart'; // Ensure UserModel is imported

// Screens
import 'package:linguaflow/screens/home/home_screen.dart';
import 'package:linguaflow/screens/discover/discover_screen.dart';
import 'package:linguaflow/screens/library/library_screen.dart';
import 'package:linguaflow/screens/profile/profile_screen.dart';
import 'package:linguaflow/screens/speak/speak_screen.dart';
import 'package:linguaflow/screens/vocabulary/vocabulary_screen.dart';
import 'package:linguaflow/screens/admin/admin_screen.dart';

// --- INHERITED WIDGET ---
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

// --- HELPER CLASS FOR NAV ITEMS ---
class _NavItem {
  final Widget screen;
  final Widget icon;
  final Widget activeIcon;
  final String label;

  _NavItem({
    required this.screen,
    required this.icon,
    required this.label,
    Widget? activeIcon,
  }) : activeIcon = activeIcon ?? icon;
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;

    // 1. FIX: Only block if strictly Loading or Initial
    // Allow 'AuthUnauthenticated' (Guests) to pass through
    if (authState is AuthInitial || authState is AuthLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // 2. FIX: Handle Null User for Guests
    final UserModel? user = (authState is AuthAuthenticated) ? authState.user : null;
    
    // Only check admin if user exists
    final bool isAdmin = user != null && AppConstants.isAdmin(user.email);

    // --- THEME AWARE COLORS ---
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final navBarColor = theme.scaffoldBackgroundColor;
    final selectedColor = colorScheme.primary;
    final unselectedColor = colorScheme.onSurface.withOpacity(0.5);
    final borderColor = theme.dividerColor;

    // ----------------------------------------------------------------------
    // 3. DEFINE NAVIGATION ITEMS
    // ----------------------------------------------------------------------
    List<_NavItem> navItems = [
      _NavItem(
        screen: HomeScreen(),
        icon: const Icon(Icons.home_outlined),
        activeIcon: const Icon(Icons.home_filled),
        label: 'Home',
      ),
      _NavItem(
        screen: const LibraryScreen(),
        icon: const Icon(Icons.library_books_outlined),
        activeIcon: const Icon(Icons.library_books_rounded),
        label: 'Library',
      ),
      _NavItem(
        screen: const VocabularyScreen(),
        icon: const Icon(Icons.school_outlined),
        activeIcon: const Icon(Icons.school_rounded),
        label: 'Vocabulary',
      ),

      _NavItem(
        screen: const DiscoverScreen(),
        icon: const Padding(
          padding: EdgeInsets.only(bottom: 4.0),
          child: FaIcon(FontAwesomeIcons.magnifyingGlass, size: 20),
        ),
        label: 'Discover',
      ),
      _NavItem(
        screen: SpeakScreen(),
        icon: FaIcon(FontAwesomeIcons.microphone, size: 20),
        label: 'Speak',
      ),
    ];

    // Admin Tab (Only if Admin)
    if (isAdmin) {
      navItems.add(
        _NavItem(
          screen: const AdminScreen(),
          icon: const Icon(Icons.admin_panel_settings_outlined),
          activeIcon: const Icon(Icons.admin_panel_settings_rounded),
          label: 'Admin',
        ),
      );
    }

    // Profile Tab (Always show - ProfileScreen handles Guest view internally)
    navItems.add(
      _NavItem(
        screen: ProfileScreen(),
        icon: const Icon(Icons.person_outline),
        activeIcon: const Icon(Icons.person_rounded),
        label: 'Profile',
      ),
    );

    // ----------------------------------------------------------------------
    // 4. BUILD LAYOUT
    // ----------------------------------------------------------------------
    return ActiveTabNotifier(
      activeIndex: _currentIndex,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Breakpoint: 900px
          final isDesktop = constraints.maxWidth >= 900;

          if (isDesktop) {
            // ============================================================
            // DESKTOP LAYOUT
            // ============================================================
            return Scaffold(
              backgroundColor: navBarColor,
              body: Row(
                children: [
                  NavigationRail(
                    backgroundColor: navBarColor,
                    selectedIndex: _currentIndex,
                    onDestinationSelected: (index) {
                      setState(() => _currentIndex = index);
                    },
                    labelType: NavigationRailLabelType.all,
                    groupAlignment: 0.0,
                    indicatorColor: colorScheme.secondary.withOpacity(0.08),
                    selectedIconTheme: IconThemeData(color: selectedColor),
                    unselectedIconTheme: IconThemeData(color: unselectedColor),
                    selectedLabelTextStyle: TextStyle(
                      color: selectedColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                    unselectedLabelTextStyle: TextStyle(
                      color: unselectedColor,
                      fontWeight: FontWeight.w500,
                      fontSize: 11,
                    ),
                    leading: Padding(
                      padding: const EdgeInsets.only(bottom: 32.0, top: 16.0),
                      child: Image.asset(
                        'assets/images/linguaflow_logo_transparent.png',
                        height: 40,
                        width: 40,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.language,
                          size: 40,
                          color: selectedColor,
                        ),
                      ),
                    ),
                    trailing: Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: VerticalDivider(
                          width: 1,
                          thickness: 1,
                          color: borderColor,
                        ),
                      ),
                    ),
                    destinations: navItems.map((item) {
                      return NavigationRailDestination(
                        icon: item.icon,
                        selectedIcon: item.activeIcon,
                        label: Text(item.label),
                      );
                    }).toList(),
                  ),
                  Expanded(
                    child: IndexedStack(
                      index: _currentIndex,
                      children: navItems.map((e) => e.screen).toList(),
                    ),
                  ),
                ],
              ),
            );
          } else {
            // ============================================================
            // MOBILE LAYOUT
            // ============================================================
            return Scaffold(
              body: IndexedStack(
                index: _currentIndex,
                children: navItems.map((e) => e.screen).toList(),
              ),
              bottomNavigationBar: Theme(
                data: theme.copyWith(
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: navBarColor,
                    border: Border(
                      top: BorderSide(color: borderColor, width: 0.5),
                    ),
                  ),
                  child: BottomNavigationBar(
                    currentIndex: _currentIndex,
                    onTap: (index) => setState(() => _currentIndex = index),
                    type: BottomNavigationBarType.fixed,
                    backgroundColor: navBarColor,
                    selectedItemColor: selectedColor,
                    unselectedItemColor: unselectedColor,
                    selectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 11,
                    ),
                    elevation: 0,
                    showUnselectedLabels: true,
                    items: navItems.map((item) {
                      return BottomNavigationBarItem(
                        icon: item.icon,
                        activeIcon: item.activeIcon,
                        label: item.label,
                      );
                    }).toList(),
                  ),
                ),
              ),
            );
          }
        },
      ),
    );
  }
}