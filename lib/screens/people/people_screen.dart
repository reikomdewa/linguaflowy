import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_event.dart';
import 'package:linguaflow/blocs/auth/auth_state.dart';
import 'package:linguaflow/models/user_model.dart';
import 'package:linguaflow/services/people_service.dart';
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

  // Theme Colors
  final Color _bgDark = const Color(0xFF15161A);
  final Color _primaryPink = const Color(0xFFE91E63);
  final Color _cardColor = const Color(0xFF1E2025);

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
        final currentUser = (context.read<AuthBloc>().state as AuthAuthenticated).user;
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
      // Important: Apply filters immediately after fetching data
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
        if (user.nativeLanguage.toLowerCase() == filterCode) matchesLanguage = true;
        if (user.additionalNativeLanguages.any((l) => l.toLowerCase() == filterCode)) matchesLanguage = true;
        // Match Target (Learning)
        if (user.targetLanguages.any((l) => l.toLowerCase() == filterCode)) matchesLanguage = true;

        if (!matchesLanguage) return false;

        // 2. Online Filter
        if (_filterOnlineOnly && !user.isOnline) return false;
        
        // 3. Reviews Filter
        if (_filterHasReviews && user.references.isEmpty) return false;

        // 4. Topic Filter
        if (_filterTopic != null) {
          bool hasTopic = user.topics.any((t) => t.toLowerCase() == _filterTopic!.toLowerCase());
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

  // 1. VIEW FILTER SHEET (User's Languages Only)
  void _showLanguageFilterSheet() {
    final state = context.read<AuthBloc>().state;
    List<String> userLanguages = ['en'];
    
    if (state is AuthAuthenticated) {
      // Build Unique List: Current + Native + Targets
      final Set<String> unique = {};
      if (state.user.currentLanguage.isNotEmpty) unique.add(state.user.currentLanguage);
      unique.add(state.user.nativeLanguage);
      unique.addAll(state.user.targetLanguages);
      userLanguages = unique.toList();
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: _cardColor,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Filter by Language", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: userLanguages.map((code) {
                      final isSelected = _selectedLanguageCode == code;
                      return ActionChip(
                        avatar: Text(LanguageHelper.getFlagEmoji(code)),
                        label: Text(LanguageHelper.getLanguageName(code)),
                        backgroundColor: isSelected ? _primaryPink : Colors.black12,
                        labelStyle: const TextStyle(color: Colors.white),
                        onPressed: () {
                          // Change Filter Locally
                          setState(() => _selectedLanguageCode = code);
                          _applyFilters();
                          Navigator.pop(context);
                          
                          // Optional: Sync back to Bloc
                          context.read<AuthBloc>().add(AuthTargetLanguageChanged(code));
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
                      icon: Icon(Icons.add, color: _primaryPink),
                      label: Text("Start learning a new language", style: TextStyle(color: _primaryPink)),
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 2. ADD LANGUAGE SHEET (All Languages, Helper Order)
  void _showAddLanguageSheet() {
    // Use Helper order directly
    final entries = LanguageHelper.availableLanguages.entries.toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: _cardColor,
      isScrollControlled: true, 
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5, // 50% Initial Height
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Add New Language", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ),
              const Divider(height: 1, color: Colors.white12),
              
              Expanded(
                child: ListView.separated(
                  controller: controller, // Enables Dragging
                  itemCount: entries.length,
                  padding: const EdgeInsets.only(bottom: 20),
                  separatorBuilder: (_, __) => const Divider(color: Colors.white12, height: 1),
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    final code = entry.key;
                    final name = entry.value;
                    final flag = LanguageHelper.getFlagEmoji(code);
                    
                    final isSelected = _selectedLanguageCode == code;

                    return ListTile(
                      leading: Text(flag, style: const TextStyle(fontSize: 24)),
                      title: Text(name, style: const TextStyle(color: Colors.white, fontSize: 16)),
                      trailing: isSelected ? Icon(Icons.check, color: _primaryPink) : null,
                      onTap: () {
                        // 1. Update Backend
                        context.read<AuthBloc>().add(AuthTargetLanguageChanged(code));
                        
                        // 2. Update UI Filter
                        setState(() => _selectedLanguageCode = code);
                        _applyFilters();
                        
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Switched to $name")));
                      },
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

  void _showTopicFilterSheet() {
    final Set<String> allTopics = {};
    for (var u in _allFetchedUsers) {
      allTopics.addAll(u.topics);
    }
    
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardColor,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Filter by Topic", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  if (allTopics.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text("No topics found in this list.", style: TextStyle(color: Colors.grey)),
                    )
                  else
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        ActionChip(
                          label: const Text("All Topics"),
                          backgroundColor: _filterTopic == null ? _primaryPink : Colors.black12,
                          labelStyle: const TextStyle(color: Colors.white),
                          onPressed: () {
                            setState(() => _filterTopic = null);
                            _applyFilters();
                            Navigator.pop(context);
                          },
                        ),
                        ...allTopics.map((topic) => ActionChip(
                          label: Text(topic),
                          backgroundColor: _filterTopic == topic ? _primaryPink : Colors.black12,
                          labelStyle: const TextStyle(color: Colors.white),
                          onPressed: () {
                            setState(() => _filterTopic = topic);
                            _applyFilters();
                            Navigator.pop(context);
                          },
                        ))
                      ],
                    )
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
      MaterialPageRoute(
        builder: (context) => ProfileDetailsScreen(user: user),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
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
        backgroundColor: _bgDark,
        body: Column(
          children: [
            _buildCustomTabBar(),
            
            // Animated Filters
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: _isFilterMenuVisible ? 55.0 : 0.0,
              curve: Curves.easeInOut,
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: SizedBox(
                  height: 55.0,
                  child: _buildFilters(),
                ),
              ),
            ),

            // Content
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: _primaryPink))
                  : _visibleUsers.isEmpty
                      ? _buildEmptyState()
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
                                onTap: () => _navigateToProfile(_visibleUsers[index]),
                                cardColor: _cardColor,
                                primaryColor: _primaryPink,
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

  Widget _buildCustomTabBar() {
    return Container(
      color: _bgDark,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.white12, width: 1)),
        ),
        child: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 2,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(text: "All"),
            Tab(text: "Nearby"),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    final langName = LanguageHelper.getLanguageName(_selectedLanguageCode);
    final flag = LanguageHelper.getFlagEmoji(_selectedLanguageCode);

    return Container(
      color: _bgDark,
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            GestureDetector(
              onTap: _showLanguageFilterSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  border: Border.all(color: _primaryPink),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(children: [
                  Text(flag, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Text(langName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 16),
                ]),
              ),
            ),
            const SizedBox(width: 8),
            
            _buildFilterChip(label: _filterTopic ?? "Topics", icon: Icons.tag, isSelected: _filterTopic != null, onTap: _showTopicFilterSheet),
            const SizedBox(width: 8),
            _buildFilterChip(label: "Reviews", icon: Icons.star_border, isSelected: _filterHasReviews, onTap: _toggleReviewsFilter),
            const SizedBox(width: 8),
            _buildFilterChip(label: "Online", icon: Icons.circle, iconColor: _filterOnlineOnly ? Colors.greenAccent : Colors.green, isSelected: _filterOnlineOnly, onTap: _toggleOnlineFilter),
            
            const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: SizedBox(height: 24, child: VerticalDivider(width: 1, color: Colors.white24))),
            
            GestureDetector(
              onTap: _showAddLanguageSheet,
              child: Row(children: [
                Icon(Icons.add, color: _primaryPink, size: 20),
                const SizedBox(width: 4),
                Text("Add language", style: TextStyle(color: _primaryPink, fontWeight: FontWeight.w600, fontSize: 15)),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label, 
    required VoidCallback onTap, 
    IconData? icon, 
    Color? iconColor,
    bool isSelected = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white12 : Colors.transparent,
          border: Border.all(color: isSelected ? _primaryPink : Colors.white30),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: iconColor ?? (isSelected ? _primaryPink : Colors.white)),
            const SizedBox(width: 6)
          ],
          Text(
            label, 
            style: TextStyle(
              color: isSelected ? _primaryPink : Colors.white, 
              fontWeight: FontWeight.w500, 
              fontSize: 13
            )
          ),
          if (!isSelected) ...[
             const SizedBox(width: 4),
             const Icon(Icons.keyboard_arrow_down, color: Colors.grey, size: 16),
          ]
        ]),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.filter_list_off, size: 60, color: Colors.grey[700]),
          const SizedBox(height: 16),
          Text(
            _allFetchedUsers.isEmpty ? "No users found." : "No users match your filters.", 
            style: TextStyle(color: Colors.grey[500])
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
             )
        ],
      ),
    );
  }
}