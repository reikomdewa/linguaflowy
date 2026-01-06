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

// --- INHERITED WIDGET (For passing active tab down the tree) ---
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

// --- HELPER CLASS ---
class _NavItem {
  final Widget screen;
  final Widget icon;
  final Widget activeIcon;
  final String label;
  // If true, this item appears in the Mobile Bottom Bar (limited to 6)
  final bool showOnMobile; 

  _NavItem({
    required this.screen,
    required this.icon,
    required this.label,
    this.showOnMobile = false,
    Widget? activeIcon,
  }) : activeIcon = activeIcon ?? icon;
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  // This tracks the ACTUAL page being shown (Index in allNavItems)
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;

    // 1. Loading Check
    if (authState is AuthInitial || authState is AuthLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // 2. User & Admin Check
    final UserModel? user = (authState is AuthAuthenticated) ? authState.user : null;
    final bool isAdmin = user != null && AppConstants.isAdmin(user.email);

    // 3. Layout Check
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
    // 4. DEFINE ALL NAVIGATION ITEMS (Single Source of Truth)
    // ----------------------------------------------------------------------
    // This list defines the order for IndexedStack. It must NEVER change length 
    // dynamically based on resize, or state will be lost.
    List<_NavItem> allNavItems = [
      // 0. Home (Mobile: YES)
      _NavItem(
        screen: HomeScreen(),
        icon: const Icon(Icons.home_outlined),
        activeIcon: const Icon(Icons.home_filled),
        label: 'Home',
        showOnMobile: true,
      ),
      // 1. Library (Mobile: YES)
      _NavItem(
        screen: const LibraryScreen(),
        icon: const Icon(Icons.library_books_outlined),
        activeIcon: const Icon(Icons.library_books_rounded),
        label: 'Library',
        showOnMobile: true,
      ),
      // 2. Vocabulary (Mobile: YES)
      _NavItem(
        screen: const VocabularyScreen(),
        icon: const Icon(Icons.school_outlined),
        activeIcon: const Icon(Icons.school_rounded),
        label: 'Vocabulary',
        showOnMobile: true,
      ),
      // 3. Discover (Mobile: YES)
      _NavItem(
        screen: const DiscoverScreen(),
        icon: const Padding(
          padding: EdgeInsets.only(bottom: 4.0),
          child: FaIcon(FontAwesomeIcons.magnifyingGlass, size: 20),
        ),
        label: 'Discover',
        showOnMobile: true,
      ),
      // 4. Speak (Mobile: YES)
      _NavItem(
        screen: SpeakScreen(),
        icon: const FaIcon(FontAwesomeIcons.microphone, size: 20),
        label: 'Speak',
        showOnMobile: true,
      ),
      // 5. Community (Desktop Only)
      _NavItem(
        screen: const CommunityScreen(),
        icon: const Icon(Icons.people_outline),
        activeIcon: const Icon(Icons.people),
        label: 'Community',
        showOnMobile: false, 
      ),
      // 6. Inbox (Desktop Only - but viewable on mobile if resized)
      _NavItem(
        screen: const InboxScreen(),
        icon: const Icon(Icons.message_outlined),
        activeIcon: const Icon(Icons.message),
        label: 'Inbox',
        showOnMobile: false, 
      ),
      // 7. Profile (Mobile: YES)
      _NavItem(
        screen: ProfileScreen(),
        icon: const Icon(Icons.person_outline),
        activeIcon: const Icon(Icons.person_rounded),
        label: 'Profile',
        showOnMobile: true,
      ),
    ];

    // Add Admin if applicable (Desktop Only)
    if (isAdmin) {
      allNavItems.add(
        _NavItem(
          screen: const AdminScreen(),
          icon: const Icon(Icons.admin_panel_settings_outlined),
          activeIcon: const Icon(Icons.admin_panel_settings_rounded),
          label: 'Admin',
          showOnMobile: true,
        ),
      );
    }

    // ----------------------------------------------------------------------
    // 5. PREPARE MOBILE NAV BAR ITEMS
    // ----------------------------------------------------------------------
    // We map the filtered items to their ORIGINAL indices in the main list.
    // This lets us click a mobile tab and update the main _currentIndex correctly.
    final mobileBottomBarConfig = <Map<String, dynamic>>[];
    
    // We also need to calculate which "Mobile Tab" is active.
    // If we are on a page NOT in the mobile list (e.g. Inbox), we default to 0 (Home)
    // purely for the visual highlight, but the Body still shows Inbox.
    int visualMobileIndex = 0; 

    for (int i = 0; i < allNavItems.length; i++) {
      if (allNavItems[i].showOnMobile) {
        mobileBottomBarConfig.add({
          'item': allNavItems[i],
          'originalIndex': i,
        });

        // If the main global index matches this item, this is our active tab
        if (_currentIndex == i) {
          visualMobileIndex = mobileBottomBarConfig.length - 1;
        }
      }
    }

    // ----------------------------------------------------------------------
    // 6. BUILD UI
    // ----------------------------------------------------------------------
    return ActiveTabNotifier(
      activeIndex: _currentIndex,
      child: Scaffold(
        backgroundColor: navBarColor,
        
        // --- BODY (Desktop & Mobile share this to preserve state) ---
        body: isDesktop
            ? Row(
                children: [
                  // --- DESKTOP RAIL ---
                  NavigationRail(
                    backgroundColor: navBarColor,
                    // Rail shows ALL items (or you can filter if you want some hidden on desktop)
                    selectedIndex: _currentIndex,
                    onDestinationSelected: (index) => setState(() => _currentIndex = index),
                    labelType: NavigationRailLabelType.all,
                    groupAlignment: 0.0,
                    indicatorColor: colorScheme.secondary.withOpacity(0.08),
                    selectedIconTheme: IconThemeData(color: selectedColor),
                    unselectedIconTheme: IconThemeData(color: unselectedColor),
                    selectedLabelTextStyle: TextStyle(
                        color: selectedColor, fontWeight: FontWeight.w700, fontSize: 11),
                    unselectedLabelTextStyle: TextStyle(
                        color: unselectedColor, fontWeight: FontWeight.w500, fontSize: 11),
                    leading: Padding(
                      padding: const EdgeInsets.only(bottom: 32.0, top: 16.0),
                      child: Image.asset(
                        'assets/images/linguaflow_logo_transparent.png',
                        height: 40, width: 40,
                        errorBuilder: (_,__,___) => Icon(Icons.language, size: 40, color: selectedColor),
                      ),
                    ),
                    trailing: Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: VerticalDivider(width: 1, thickness: 1, color: borderColor),
                      ),
                    ),
                    destinations: allNavItems.map((item) {
                      return NavigationRailDestination(
                        icon: item.icon,
                        selectedIcon: item.activeIcon,
                        label: Text(item.label),
                      );
                    }).toList(),
                  ),
                  
                  // --- CONTENT AREA ---
                  Expanded(
                    child: IndexedStack(
                      index: _currentIndex,
                      children: allNavItems.map((e) => e.screen).toList(),
                    ),
                  ),
                ],
              )
            // --- MOBILE BODY ---
            : IndexedStack(
                index: _currentIndex,
                children: allNavItems.map((e) => e.screen).toList(),
              ),

        // --- MOBILE BOTTOM NAVIGATION BAR ---
        bottomNavigationBar: !isDesktop
            ? Theme(
                data: theme.copyWith(
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: navBarColor,
                    border: Border(top: BorderSide(color: borderColor, width: 0.5)),
                  ),
                  child: BottomNavigationBar(
                    // Safe index: defaults to 0 if we are on a Desktop-only page
                    currentIndex: visualMobileIndex,
                    onTap: (navIndex) {
                      // Lookup the REAL index from our config map
                      final int realIndex = mobileBottomBarConfig[navIndex]['originalIndex'];
                      setState(() => _currentIndex = realIndex);
                    },
                    // Use FIXED type because we have 6 items
                    type: BottomNavigationBarType.fixed,
                    backgroundColor: navBarColor,
                    selectedItemColor: selectedColor,
                    unselectedItemColor: unselectedColor,
                    selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
                    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
                    elevation: 0,
                    showUnselectedLabels: true,
                    items: mobileBottomBarConfig.map((config) {
                      final _NavItem item = config['item'];
                      return BottomNavigationBarItem(
                        icon: item.icon,
                        activeIcon: item.activeIcon,
                        label: item.label,
                      );
                    }).toList(),
                  ),
                ),
              )
            : null,
      ),
    );
  }
}