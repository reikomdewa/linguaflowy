import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_state.dart';
import 'package:linguaflow/models/user_model.dart';
import 'package:linguaflow/services/people_service.dart';
import 'package:linguaflow/utils/language_helper.dart'; // Helper Import
import 'package:linguaflow/screens/people/widgets/people_card.dart'; // Card Import

class PeopleScreen extends StatefulWidget {
  const PeopleScreen({Key? key}) : super(key: key);

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final PeopleService _peopleService = PeopleService();
  
  List<UserModel> _users = [];
  bool _isLoading = true;
  String? _currentUserId;
  List<String> _blockedUserIds = [];

  // Theme
  final Color _bgDark = const Color(0xFF15161A);
  final Color _primaryPink = const Color(0xFFE91E63);
  final Color _cardColor = const Color(0xFF1E2025);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
      _currentUserId = state.user.id;
      _blockedUserIds = state.user.blockedUsers;
      _loadUsersForTab();
    }
  }

  Future<void> _loadUsersForTab() async {
    if (_currentUserId == null) return;
    setState(() => _isLoading = true);

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
        // All & Travel Logic
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
        _users = fetchedUsers;
        _isLoading = false;
      });
    }
  }

  // --- UI ACTIONS ---

  void _showUserProfileDialog(UserModel user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardColor,
      isScrollControlled: true, // Allows full content
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, controller) {
            return ListView(
              controller: controller,
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "About ${user.displayName}", 
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)
                ),
                const SizedBox(height: 20),
                
                // References Section
                if (user.references.isNotEmpty) ...[
                  const Text("References", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  ...user.references.map((ref) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('"${ref.text}"', style: const TextStyle(color: Colors.white, fontStyle: FontStyle.italic)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 14),
                            const SizedBox(width: 4),
                            Text(ref.authorName, style: TextStyle(color: _primaryPink, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        )
                      ],
                    ),
                  )).toList()
                ] else 
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text("No references yet.", style: TextStyle(color: Colors.grey)),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          setState(() {
            _currentUserId = state.user.id;
            _blockedUserIds = state.user.blockedUsers;
          });
          _loadUsersForTab();
        }
      },
      child: Scaffold(
        backgroundColor: _bgDark,
        appBar: AppBar(
          backgroundColor: _bgDark,
          elevation: 0,
          title: _buildCustomTabBar(),
          centerTitle: true,
        ),
        body: Column(
          children: [
            const SizedBox(height: 10),
            _buildFilters(),
            const SizedBox(height: 10),
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: _primaryPink))
                  : _users.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          itemCount: _users.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            return PeopleCard(
                              user: _users[index],
                              onTap: () => _showUserProfileDialog(_users[index]),
                              cardColor: _cardColor,
                              primaryColor: _primaryPink,
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomTabBar() {
    return Container(
      height: 40,
      width: double.infinity,
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
          Tab(text: "Travel"),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    String currentLangLabel = "Languages";
    final state = context.read<AuthBloc>().state;
    if (state is AuthAuthenticated && state.user.targetLanguages.isNotEmpty) {
      // Use Helper to get Full Name
      currentLangLabel = LanguageHelper.getLanguageName(state.user.targetLanguages.first);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white30),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              currentLangLabel,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () {
               // Add language logic
            },
            child: Row(
              children: [
                Icon(Icons.add, color: _primaryPink, size: 20),
                const SizedBox(width: 4),
                Text(
                  "Add language",
                  style: TextStyle(color: _primaryPink, fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 60, color: Colors.grey[700]),
          const SizedBox(height: 16),
          Text("No users found here yet.", style: TextStyle(color: Colors.grey[500])),
        ],
      ),
    );
  }
}