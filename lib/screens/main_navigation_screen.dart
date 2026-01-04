import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_state.dart';
import 'package:linguaflow/constants/constants.dart';
import 'package:linguaflow/models/user_model.dart';
import 'package:linguaflow/screens/community/community_screen.dart';

// Screens
import 'package:linguaflow/screens/home/home_screen.dart';
import 'package:linguaflow/screens/discover/discover_screen.dart';
import 'package:linguaflow/screens/inbox/inbox_screen.dart';
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

    // 1. Loading State
    if (authState is AuthInitial || authState is AuthLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // 2. User & Admin check
    final UserModel? user = (authState is AuthAuthenticated)
        ? authState.user
        : null;
    final bool isAdmin = user != null && AppConstants.isAdmin(user.email);

    // 3. Determine Layout Mode (Consistency is key: use same breakpoint everywhere)
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth >= 900;

    // --- THEME ---
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final navBarColor = theme.scaffoldBackgroundColor;
    final selectedColor = colorScheme.primary;
    final unselectedColor = colorScheme.onSurface.withOpacity(0.5);
    final borderColor = theme.dividerColor;

    // ----------------------------------------------------------------------
    // 4. DEFINE NAVIGATION ITEMS
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
        icon: const FaIcon(FontAwesomeIcons.microphone, size: 20),
        label: 'Speak',
      ),
    ];

    // -- Admin Tab --
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

    // -- Desktop Only Tabs --
    if (isDesktop) {
      // Use explicit insertion indices carefully based on your list above
      // Current base length is 5 (or 6 if admin)

      // Add Community
      navItems.add(
        _NavItem(
          screen: const CommunityScreen(),
          icon: const Icon(Icons.people),
          activeIcon: const Icon(Icons.people),
          label: 'Community',
        ),
      );

      // Add Inbox
      navItems.add(
        _NavItem(
          screen: const InboxScreen(),
          icon: const Icon(Icons.message),
          activeIcon: const Icon(Icons.message),
          label: 'Inbox',
        ),
      );
    }

    // -- Profile Tab (Always Last) --
    navItems.add(
      _NavItem(
        screen: ProfileScreen(),
        icon: const Icon(Icons.person_outline),
        activeIcon: const Icon(Icons.person_rounded),
        label: 'Profile',
      ),
    );

    // ----------------------------------------------------------------------
    // 5. SAFETY CHECK (CRITICAL FIX)
    // ----------------------------------------------------------------------
    // If we switched from Desktop -> Mobile, _currentIndex might be pointing
    // to an index that no longer exists. We clamp it here for rendering.
    final int effectiveIndex = (_currentIndex >= navItems.length)
        ? 0
        : _currentIndex;

    // ----------------------------------------------------------------------
    // 6. BUILD LAYOUT
    // ----------------------------------------------------------------------
    return ActiveTabNotifier(
      activeIndex: effectiveIndex,
      child: Scaffold(
        backgroundColor: navBarColor,
        body: isDesktop
            // ============================================================
            // DESKTOP LAYOUT
            // ============================================================
            ? Row(
                children: [
                  NavigationRail(
                    backgroundColor: navBarColor,
                    // Use effectiveIndex to prevent crash during resize
                    selectedIndex: effectiveIndex,
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
                    // Use effectiveIndex
                    child: IndexedStack(
                      index: effectiveIndex,
                      children: navItems.map((e) => e.screen).toList(),
                    ),
                  ),
                ],
              )
            // ============================================================
            // MOBILE LAYOUT
            // ============================================================
            : Column(
                children: [
                  Expanded(
                    // Use effectiveIndex
                    child: IndexedStack(
                      index: effectiveIndex,
                      children: navItems.map((e) => e.screen).toList(),
                    ),
                  ),
                  Theme(
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
                        // Use effectiveIndex (Prevents RangeError)
                        currentIndex: effectiveIndex,
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
                ],
              ),
      ),
    );
  }
}
