import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_event.dart';
import 'package:linguaflow/blocs/auth/auth_state.dart';
import 'package:linguaflow/blocs/speak/room/room_bloc.dart';
import 'package:linguaflow/blocs/speak/room/room_state.dart';
import 'package:linguaflow/models/private_chat_models.dart';
import 'package:linguaflow/models/user_model.dart';
import 'package:linguaflow/screens/inbox/inbox_screen.dart';
import 'package:linguaflow/services/people_service.dart';
import 'package:linguaflow/services/speak/private_chat_service.dart';
import 'package:linguaflow/utils/auth_guard.dart';
import 'package:linguaflow/utils/language_helper.dart';
import 'package:linguaflow/screens/people/widgets/people_card.dart';
import 'package:linguaflow/screens/people/profile_details_screen.dart';

class PeopleScreen extends StatefulWidget {
  const PeopleScreen({Key? key}) : super(key: key);

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late TabController _tabController;
  final PeopleService _peopleService = PeopleService();

  // Data State
  List<UserModel> _allFetchedUsers = [];
  List<UserModel> _visibleUsers = [];
  bool _isLoading = true;
  String? _currentUserId;
  List<String> _blockedUserIds = [];

  // Filter UI State
  bool _isFilterMenuVisible = true;

  // Active Filters
  bool _filterOnlineOnly = false;
  bool _filterHasReviews = false;
  String? _filterTopic;
  String _selectedLanguageCode = 'en';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    _loadUsersForTab();
  }

  void _initializeData() {
    final state = context.read<AuthBloc>().state;
    if (state is AuthAuthenticated) {
      final user = state.user;

      setState(() {
        _currentUserId = user.id;
        _blockedUserIds = user.blockedUsers;

        // Default to current -> first target -> native -> en
        if (user.currentLanguage.isNotEmpty) {
          _selectedLanguageCode = user.currentLanguage;
        } else if (user.targetLanguages.isNotEmpty) {
          _selectedLanguageCode = user.targetLanguages.first;
        } else {
          _selectedLanguageCode = 'en';
        }
      });

      _loadUsersForTab();
    }
  }

  Future<void> _loadUsersForTab() async {
    if (_currentUserId == null) return;

    // Only show loading spinner on initial fetch
    if (_allFetchedUsers.isEmpty) setState(() => _isLoading = true);

    List<UserModel> fetchedUsers = [];
    try {
      if (_tabController.index == 1) {
        // Nearby Logic
        final currentUser =
            (context.read<AuthBloc>().state as AuthAuthenticated).user;
        fetchedUsers = await _peopleService.getNearbyUsers(
          currentUserId: _currentUserId!,
          myCountryCode: currentUser.countryCode ?? 'US',
          blockedUserIds: _blockedUserIds,
        );
      } else {
        // All Community Logic
        fetchedUsers = await _peopleService.getCommunityUsers(
          currentUserId: _currentUserId!,
          blockedUserIds: _blockedUserIds,
        );
      }
    } catch (e) {
      print("Error loading users: $e");
    }

    if (mounted) {
      setState(() {
        _allFetchedUsers = fetchedUsers;
        _isLoading = false;
      });
      _applyFilters();
    }
  }

  // --- CORE FILTER LOGIC ---
  void _applyFilters() {
    setState(() {
      _visibleUsers = _allFetchedUsers.where((user) {
        // 1. Language Filter
        bool matchesLanguage = false;
        final filterCode = _selectedLanguageCode.toLowerCase();

        // Match Native
        if (user.nativeLanguage.toLowerCase() == filterCode)
          matchesLanguage = true;
        if (user.additionalNativeLanguages.any(
          (l) => l.toLowerCase() == filterCode,
        ))
          matchesLanguage = true;
        // Match Target (Learning)
        if (user.targetLanguages.any((l) => l.toLowerCase() == filterCode))
          matchesLanguage = true;

        if (!matchesLanguage) return false;

        // 2. Online Filter
        if (_filterOnlineOnly && !user.isOnline) return false;

        // 3. Reviews Filter
        if (_filterHasReviews && user.references.isEmpty) return false;

        // 4. Topic Filter
        if (_filterTopic != null) {
          bool hasTopic = user.topics.any(
            (t) => t.toLowerCase() == _filterTopic!.toLowerCase(),
          );
          if (!hasTopic) return false;
        }

        return true;
      }).toList();
    });
  }

  void _toggleOnlineFilter() {
    setState(() => _filterOnlineOnly = !_filterOnlineOnly);
    _applyFilters();
  }

  void _toggleReviewsFilter() {
    setState(() => _filterHasReviews = !_filterHasReviews);
    _applyFilters();
  }

  // --- BOTTOM SHEETS ---

  // REUSABLE SHEET BUILDER
  void _showLanguageSheet({
    required String title,
    required Function(String code, String name) onLanguageSelected,
  }) {
    final theme = Theme.of(context);
    final entries = LanguageHelper.availableLanguages.entries.toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor, // Theme aware
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 15,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: theme.hintColor),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: theme.dividerColor),

              Expanded(
                child: ListView.separated(
                  controller: controller,
                  itemCount: entries.length,
                  padding: const EdgeInsets.only(bottom: 20),
                  separatorBuilder: (_, __) =>
                      Divider(color: theme.dividerColor, height: 1),
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    final code = entry.key;
                    final name = entry.value;
                    final flag = LanguageHelper.getFlagEmoji(code);

                    final isSelected = _selectedLanguageCode == code;

                    return ListTile(
                      leading: Text(flag, style: const TextStyle(fontSize: 24)),
                      title: Text(
                        name,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 16,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(
                              Icons.check,
                              color: theme.colorScheme.secondary,
                            )
                          : null,
                      onTap: () => onLanguageSelected(code, name),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 1. VIEW FILTER SHEET (User's Languages Only)
  void _showLanguageFilterSheet() {
    final theme = Theme.of(context);
    final state = context.read<AuthBloc>().state;
    List<String> userLanguages = ['en'];

    if (state is AuthAuthenticated) {
      final Set<String> unique = {};
      if (state.user.currentLanguage.isNotEmpty)
        unique.add(state.user.currentLanguage);
      unique.add(state.user.nativeLanguage);
      unique.addAll(state.user.targetLanguages);
      userLanguages = unique.toList();
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor, // Theme aware
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Filter by Language",
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: userLanguages.map((code) {
                      final isSelected = _selectedLanguageCode == code;
                      return ActionChip(
                        avatar: Text(LanguageHelper.getFlagEmoji(code)),
                        label: Text(LanguageHelper.getLanguageName(code)),
                        // Theme colors for Chip
                        backgroundColor: isSelected
                            ? theme.colorScheme.secondary
                            : theme.scaffoldBackgroundColor,
                        side: BorderSide(
                          color: isSelected
                              ? Colors.transparent
                              : theme.dividerColor,
                        ),
                        labelStyle: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : theme.colorScheme.onSurface,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        onPressed: () {
                          setState(() => _selectedLanguageCode = code);
                          _applyFilters();
                          Navigator.pop(context);
                          context.read<AuthBloc>().add(
                            AuthTargetLanguageChanged(code),
                          );
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showAddLanguageSheet();
                      },
                      icon: Icon(Icons.add, color: theme.colorScheme.secondary),
                      label: Text(
                        "Start learning a new language",
                        style: TextStyle(color: theme.colorScheme.secondary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 2. ADD LANGUAGE SHEET
  void _showAddLanguageSheet() {
    _showLanguageSheet(
      title: "Add New Language",
      onLanguageSelected: (code, name) {
        context.read<AuthBloc>().add(AuthTargetLanguageChanged(code));
        setState(() => _selectedLanguageCode = code);
        _applyFilters();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Added $name to your languages!")),
        );
      },
    );
  }

  void _showTopicFilterSheet() {
    final theme = Theme.of(context);
    final Set<String> allTopics = {};
    for (var u in _allFetchedUsers) {
      allTopics.addAll(u.topics);
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Filter by Topic",
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (allTopics.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        "No topics found in this list.",
                        style: TextStyle(color: theme.hintColor),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        ActionChip(
                          label: const Text("All Topics"),
                          backgroundColor: _filterTopic == null
                              ? theme.colorScheme.secondary
                              : theme.scaffoldBackgroundColor,
                          side: BorderSide(
                            color: _filterTopic == null
                                ? Colors.transparent
                                : theme.dividerColor,
                          ),
                          labelStyle: TextStyle(
                            color: _filterTopic == null
                                ? Colors.white
                                : theme.colorScheme.onSurface,
                          ),
                          onPressed: () {
                            setState(() => _filterTopic = null);
                            _applyFilters();
                            Navigator.pop(context);
                          },
                        ),
                        ...allTopics.map(
                          (topic) => ActionChip(
                            label: Text(topic),
                            backgroundColor: _filterTopic == topic
                                ? theme.colorScheme.secondary
                                : theme.scaffoldBackgroundColor,
                            side: BorderSide(
                              color: _filterTopic == topic
                                  ? Colors.transparent
                                  : theme.dividerColor,
                            ),
                            labelStyle: TextStyle(
                              color: _filterTopic == topic
                                  ? Colors.white
                                  : theme.colorScheme.onSurface,
                            ),
                            onPressed: () {
                              setState(() => _filterTopic = topic);
                              _applyFilters();
                              Navigator.pop(context);
                            },
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- SCROLL & NAVIGATION ---

  void _onScrollNotification(UserScrollNotification notification) {
    if (notification.direction == ScrollDirection.forward) {
      if (!_isFilterMenuVisible) setState(() => _isFilterMenuVisible = true);
    } else if (notification.direction == ScrollDirection.reverse) {
      if (_isFilterMenuVisible) setState(() => _isFilterMenuVisible = false);
    }
  }

  void _navigateToProfile(UserModel user) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ProfileDetailsScreen(user: user)),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final authState = context.watch<AuthBloc>().state;
    final currentUser = (authState is AuthAuthenticated)
        ? authState.user
        : null;
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          setState(() {
            _currentUserId = state.user.id;
            _blockedUserIds = state.user.blockedUsers;
          });
          if (_allFetchedUsers.isEmpty) _loadUsersForTab();
        }
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        floatingActionButton: _buildFab(context, currentUser),
        body: Column(
          children: [
            _buildCustomTabBar(theme),

            // Animated Filters
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: _isFilterMenuVisible ? 55.0 : 0.0,
              curve: Curves.easeInOut,
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: SizedBox(height: 55.0, child: _buildFilters(theme)),
              ),
            ),

            // Content
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: theme.colorScheme.secondary,
                      ),
                    )
                  : _visibleUsers.isEmpty
                  ? _buildEmptyState(theme)
                  : NotificationListener<UserScrollNotification>(
                      onNotification: (notification) {
                        _onScrollNotification(notification);
                        return true;
                      },
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 80),
                        itemCount: _visibleUsers.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          return PeopleCard(
                            user: _visibleUsers[index],
                            onTap: () =>
                                _navigateToProfile(_visibleUsers[index]),
                            cardColor: theme.cardColor,
                            primaryColor: theme.colorScheme.secondary,
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS ---
  Widget _buildFab(BuildContext context, dynamic currentUser) {
    final theme = Theme.of(context);
    return BlocBuilder<RoomBloc, RoomState>(
      builder: (context, state) {
        final isInRoom = state.activeChatRoom != null;
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (currentUser != null) ...[
              const SizedBox(height: 16),
              FloatingActionButton(
                heroTag: 'msg_people',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const InboxScreen()),
                ),
                child: StreamBuilder<List<PrivateConversation>>(
                  stream: PrivateChatService().getInbox(currentUser.id),
                  builder: (context, snapshot) {
                    int unread = 0;
                    if (snapshot.hasData) {
                      for (var c in snapshot.data!)
                        if (c.lastSenderId != currentUser.id)
                          unread += c.unreadCount;
                    }
                    return Badge(
                      isLabelVisible: unread > 0,
                      label: Text(unread > 99 ? '99+' : '$unread'),
                      backgroundColor: Colors.red,
                      offset: const Offset(4, -4),
                      child: Icon(
                        isInRoom
                            ? Icons.chat_bubble_outline_rounded
                            : Icons.message_rounded,
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildCustomTabBar(ThemeData theme) {
    return Container(
      color: theme.scaffoldBackgroundColor,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: theme.dividerColor, width: 1),
          ),
        ),
        child: TabBar(
          controller: _tabController,
          indicatorColor: theme.colorScheme.onSurface,
          indicatorWeight: 2,
          labelColor: theme.colorScheme.onSurface,
          unselectedLabelColor: theme.hintColor,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          tabs: const [
            Tab(text: "All"),
            Tab(text: "Nearby"),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters(ThemeData theme) {
    final langName = LanguageHelper.getLanguageName(_selectedLanguageCode);
    final flag = LanguageHelper.getFlagEmoji(_selectedLanguageCode);
    final activeColor = theme.colorScheme.secondary;

    return Container(
      color: theme.scaffoldBackgroundColor,
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            GestureDetector(
              onTap: _showLanguageFilterSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  border: Border.all(color: activeColor),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Text(flag, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(
                      langName,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_down,
                      color: theme.colorScheme.onSurface,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),

            _buildFilterChip(
              theme,
              label: _filterTopic ?? "Topics",
              icon: Icons.tag,
              isSelected: _filterTopic != null,
              onTap: _showTopicFilterSheet,
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              theme,
              label: "Reviews",
              icon: Icons.star_border,
              isSelected: _filterHasReviews,
              onTap: _toggleReviewsFilter,
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              theme,
              label: "Online",
              icon: Icons.circle,
              iconColor: _filterOnlineOnly ? Colors.greenAccent : Colors.green,
              isSelected: _filterOnlineOnly,
              onTap: _toggleOnlineFilter,
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                height: 24,
                child: VerticalDivider(width: 1, color: theme.dividerColor),
              ),
            ),

            GestureDetector(
              onTap: _showAddLanguageSheet,
              child: Row(
                children: [
                  Icon(Icons.add, color: activeColor, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    "Add language",
                    style: TextStyle(
                      color: activeColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(
    ThemeData theme, {
    required String label,
    required VoidCallback onTap,
    IconData? icon,
    Color? iconColor,
    bool isSelected = false,
  }) {
    final activeColor = theme.colorScheme.secondary;
    final inactiveColor = theme.colorScheme.onSurface;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withOpacity(0.1) : Colors.transparent,
          border: Border.all(
            color: isSelected ? activeColor : theme.dividerColor,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: iconColor ?? (isSelected ? activeColor : inactiveColor),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? activeColor : inactiveColor,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
            if (!isSelected) ...[
              const SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down, color: theme.hintColor, size: 16),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.filter_list_off, size: 60, color: theme.hintColor),
          const SizedBox(height: 16),
          Text(
            _allFetchedUsers.isEmpty
                ? "No users found."
                : "No users match your filters.",
            style: TextStyle(color: theme.hintColor),
          ),
          if (_allFetchedUsers.isNotEmpty)
            TextButton(
              onPressed: () {
                setState(() {
                  _filterOnlineOnly = false;
                  _filterHasReviews = false;
                  _filterTopic = null;
                });
                _applyFilters();
              },
              child: const Text("Clear Filters"),
            ),
        ],
      ),
    );
  }
}
