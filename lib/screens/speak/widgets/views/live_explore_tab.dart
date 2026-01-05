import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_state.dart';
import 'package:linguaflow/blocs/speak/room/room_bloc.dart';
import 'package:linguaflow/blocs/speak/room/room_event.dart';
import 'package:linguaflow/blocs/speak/room/room_state.dart';
import 'package:linguaflow/blocs/speak/tutor/tutor_bloc.dart';
import 'package:linguaflow/blocs/speak/tutor/tutor_event.dart';
import 'package:linguaflow/blocs/speak/tutor/tutor_state.dart';
import 'package:linguaflow/models/private_chat_models.dart';
import 'package:linguaflow/models/speak/speak_models.dart';
import 'package:linguaflow/screens/inbox/inbox_screen.dart';
import 'package:linguaflow/screens/speak/create_tutor_profile_screen.dart';
import 'package:linguaflow/screens/speak/widgets/cards/room_card.dart';
import 'package:linguaflow/screens/speak/widgets/cards/tutor_card.dart';
import 'package:linguaflow/screens/speak/widgets/filter_bottom_sheet.dart';
import 'package:linguaflow/screens/speak/widgets/sheets/create_room_sheet.dart';
import 'package:linguaflow/screens/speak/widgets/speak_header.dart';
import 'package:linguaflow/screens/speak/widgets/tab_chip.dart';
import 'package:linguaflow/services/speak/private_chat_service.dart';
import 'package:linguaflow/utils/auth_guard.dart';
import 'package:linguaflow/utils/language_helper.dart';

class LiveExploreTab extends StatefulWidget {
  const LiveExploreTab({super.key});

  @override
  State<LiveExploreTab> createState() => _LiveExploreTabState();
}

class _LiveExploreTabState extends State<LiveExploreTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  int _currentTabIndex = 0; // 0: All, 1: Tutors, 2: Rooms
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() => _isSearching = !_isSearching);
    if (!_isSearching) {
      _searchController.clear();
      context.read<RoomBloc>().add(const FilterRooms(null));
      context.read<TutorBloc>().add(const FilterTutors(null));
    }
  }

  Future<void> _onRefresh() async {
    context.read<RoomBloc>().add(const LoadRooms());
    context.read<TutorBloc>().add(const LoadTutors());
    await Future.delayed(const Duration(milliseconds: 800));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final authState = context.watch<AuthBloc>().state;
    final currentUser = (authState is AuthAuthenticated)
        ? authState.user
        : null;
    final theme = Theme.of(context);

    // Using Scaffold to handle FAB properly
    return Scaffold(
      backgroundColor: Colors.transparent, // Transparent to blend with parent
      floatingActionButton: _buildFab(context, currentUser),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        // The CustomScrollView connects the App Bar behavior with the Content scrolling
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // 1. THE MAGIC SLIVER APP BAR
            // This handles the "Hide on scroll down, Show on scroll up"
            SliverAppBar(
              backgroundColor: theme.scaffoldBackgroundColor,
              elevation: 0,
              // Floating + Snap = Show immediately when scrolling up
              floating: true,
              snap: true,
              pinned: false, // false = it scrolls off screen
              automaticallyImplyLeading: false,
              toolbarHeight: 70, // Adjust based on your SpeakHeader height
              // The Search Bar goes here
              title: SpeakHeader(
                isSearching: _isSearching,
                searchController: _searchController,
                onToggleSearch: _toggleSearch,
              ),
              titleSpacing: 0,

              // The Filter Tabs go here
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(50),
                child: _buildTabSelector(context),
              ),
            ),

            // 2. SUGGESTION TEXT HEADER
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: _buildSuggestedHeader(context, currentUser),
              ),
            ),

            // 3. THE CONTENT (Slivers)
            _buildBody(context, currentUser),

            // 4. BOTTOM PADDING (For FAB)
            const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, dynamic user) {
    switch (_currentTabIndex) {
      case 0:
        return _buildMixedList(user);
      case 1:
        return _buildTutorList(user);
      case 2:
        return _buildRoomList(user);
      default:
        return const SliverToBoxAdapter(child: SizedBox());
    }
  }

  // ===========================================================================
  // SLIVER LIST BUILDER
  // ===========================================================================

  Widget _buildSliverList({
    required BuildContext context,
    required List<dynamic> items,
    required String emptyMessage,
  }) {
    // Empty State (Centered in the remaining scroll view space)
    if (items.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Text(emptyMessage, style: const TextStyle(color: Colors.grey)),
        ),
      );
    }

    // Layout Builder to switch between Grid (Desktop) and List (Mobile)
    // Note: LayoutBuilder doesn't work directly inside Slivers easily,
    // so we assume mobile-first or wrap the specific delegate logic.
    // For simplicity and performance, we'll use a responsive crossAxisCount.

    final width = MediaQuery.of(context).size.width;
    bool isDesktop = width > 700;
    int crossAxisCount = width > 1300
        ? 4
        : (width > 1000 ? 3 : (width > 700 ? 2 : 1));

    if (isDesktop) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.2,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) => _buildItem(items[index]),
            childCount: items.length,
          ),
        ),
      );
    } else {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildItem(items[index]),
            ),
            childCount: items.length,
          ),
        ),
      );
    }
  }

  Widget _buildItem(dynamic item) {
    if (item is ChatRoom) return RoomCard(room: item);
    if (item is Tutor) return TutorCard(tutor: item);
    return const SizedBox.shrink();
  }

  // --- Lists (Now returning Widgets that act as Slivers) ---

  Widget _buildMixedList(dynamic user) {
    return BlocBuilder<RoomBloc, RoomState>(
      builder: (context, roomState) {
        return BlocBuilder<TutorBloc, TutorState>(
          builder: (context, tutorState) {
            if (roomState.status == RoomStatus.loading &&
                tutorState.status == TutorStatus.loading &&
                roomState.allRooms.isEmpty) {
              return const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final List<dynamic> feedItems = [
              ...roomState.filteredRooms,
              ...tutorState.filteredTutors,
            ];
            feedItems.sort((a, b) {
              DateTime dateA = (a is ChatRoom)
                  ? a.createdAt
                  : (a as Tutor).createdAt;
              DateTime dateB = (b is ChatRoom)
                  ? b.createdAt
                  : (b as Tutor).createdAt;
              return dateB.compareTo(dateA);
            });
            return _buildSliverList(
              context: context,
              items: feedItems,
              emptyMessage: "No suggestions found.",
            );
          },
        );
      },
    );
  }

  Widget _buildTutorList(dynamic user) {
    return BlocBuilder<TutorBloc, TutorState>(
      builder: (context, state) {
        if (state.status == TutorStatus.loading && state.allTutors.isEmpty) {
          return const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return _buildSliverList(
          context: context,
          items: state.filteredTutors,
          emptyMessage: "No tutors found.",
        );
      },
    );
  }

  Widget _buildRoomList(dynamic user) {
    return BlocBuilder<RoomBloc, RoomState>(
      builder: (context, state) {
        if (state.status == RoomStatus.loading && state.allRooms.isEmpty) {
          return const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return _buildSliverList(
          context: context,
          items: state.filteredRooms,
          emptyMessage: "No active rooms.",
        );
      },
    );
  }

  // --- UI Headers & Selectors ---
  Widget _buildSuggestedHeader(BuildContext context, dynamic user) {
    String titleText = "Popular suggestions";
    if (user != null)
      titleText =
          "${LanguageHelper.getLanguageName(user.currentLanguage)} suggestions";
    return Row(
      children: [
        Icon(
          Icons.auto_awesome,
          size: 18,
          color: Theme.of(context).primaryColor,
        ),
        const SizedBox(width: 8),
        Text(
          titleText,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildTabSelector(BuildContext context) {
    return Builder(
      builder: (context) {
        final roomFilters = context.watch<RoomBloc>().state.filters;
        final tutorFilters = context.watch<TutorBloc>().state.filters;
        bool isActive(String k) =>
            roomFilters.containsKey(k) || tutorFilters.containsKey(k);

        return Container(
          color: Theme.of(
            context,
          ).scaffoldBackgroundColor, // Ensure opaque background when scrolling
          width: double.infinity,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                TabChip(
                  label: 'All',
                  isSelected: _currentTabIndex == 0,
                  onTap: () => setState(() => _currentTabIndex = 0),
                ),
                const SizedBox(width: 8),
                TabChip(
                  label: 'Tutors',
                  isSelected: _currentTabIndex == 1,
                  onTap: () => setState(() => _currentTabIndex = 1),
                ),
                const SizedBox(width: 8),
                TabChip(
                  label: 'Rooms',
                  isSelected: _currentTabIndex == 2,
                  onTap: () => setState(() => _currentTabIndex = 2),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(height: 24, child: VerticalDivider(width: 1)),
                ),
                TabChip(
                  label: 'Level',
                  isFilter: true,
                  isSelected: isActive('Language Level'),
                  onTap: () => _showFilterSheet(context, 'Language Level', [
                    'Beginner',
                    'Intermediate',
                    'Advanced',
                    'Native',
                  ]),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showFilterSheet(
    BuildContext context,
    String category,
    List<String> options,
  ) {
    String? currentVal;
    final roomBloc = context.read<RoomBloc>();
    final tutorBloc = context.read<TutorBloc>();
    if (_currentTabIndex == 1)
      currentVal = tutorBloc.state.filters[category];
    else
      currentVal = roomBloc.state.filters[category];

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => FilterBottomSheet(
        category: category,
        options: options,
        currentSelection: currentVal,
        onSelect: (val) {
          if (_currentTabIndex == 0) {
            roomBloc.add(FilterRooms(val, category: category));
            tutorBloc.add(FilterTutors(val, category: category));
          } else if (_currentTabIndex == 1)
            tutorBloc.add(FilterTutors(val, category: category));
          else
            roomBloc.add(FilterRooms(val, category: category));
        },
      ),
    );
  }

  // --- FAB ---
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
            FloatingActionButton(
              heroTag: 'create',
              backgroundColor: theme.cardColor.withOpacity(0.9),
              onPressed: () => AuthGuard.run(
                context,
                onAuthenticated: () => _showCreateOptions(context),
              ),
              child: const Icon(Icons.add_rounded, size: 32),
            ),
            if (currentUser != null) ...[
              const SizedBox(height: 16),
              FloatingActionButton(
                heroTag: 'msg',
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

  void _showCreateOptions(BuildContext context) {
    final roomBloc = context.read<RoomBloc>();
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Create New",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green.withOpacity(0.1),
                  child: const Icon(
                    FontAwesomeIcons.microphone,
                    color: Colors.green,
                    size: 20,
                  ),
                ),
                title: const Text("Start Live Room"),
                onTap: () {
                  Navigator.pop(ctx);
                  showModalBottomSheet(
                    context: context,
                    useSafeArea: true,
                    isScrollControlled: true,
                    builder: (_) => BlocProvider.value(
                      value: roomBloc,
                      child: const CreateRoomSheet(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.withOpacity(0.1),
                  child: const Icon(
                    FontAwesomeIcons.chalkboardUser,
                    color: Colors.blue,
                    size: 20,
                  ),
                ),
                title: const Text("Create Tutor Profile"),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CreateTutorProfileScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
