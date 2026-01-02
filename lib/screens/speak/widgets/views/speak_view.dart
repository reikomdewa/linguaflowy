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
import 'package:linguaflow/screens/inbox/inbox_screen.dart';
import 'package:linguaflow/services/speak/private_chat_service.dart';
import 'package:livekit_client/livekit_client.dart';

// Model and Utils imports
import 'package:linguaflow/models/speak/speak_models.dart';
import 'package:linguaflow/screens/speak/create_tutor_profile_screen.dart';
import 'package:linguaflow/screens/speak/widgets/filter_bottom_sheet.dart';
import 'package:linguaflow/screens/speak/widgets/speak_header.dart';
import 'package:linguaflow/screens/speak/widgets/tab_chip.dart';
import 'package:linguaflow/utils/language_helper.dart';

// Reusable UI components
import 'package:linguaflow/screens/speak/widgets/sheets/create_room_sheet.dart';
import 'package:linguaflow/screens/speak/widgets/cards/room_card.dart';
import 'package:linguaflow/screens/speak/widgets/sheets/room_chat_sheet.dart';
import 'package:linguaflow/screens/speak/widgets/cards/tutor_card.dart';

// Import your AuthGuard
import 'package:linguaflow/utils/auth_guard.dart';

class SpeakView extends StatefulWidget {
  const SpeakView({super.key});

  @override
  State<SpeakView> createState() => _SpeakViewState();
}

class _SpeakViewState extends State<SpeakView> {
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
    final theme = Theme.of(context);
    final authState = context.watch<AuthBloc>().state;
    final currentUser = (authState is AuthAuthenticated)
        ? authState.user
        : null;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton: _buildFab(context, currentUser),
      body: SafeArea(
        child: Column(
          children: [
            SpeakHeader(
              isSearching: _isSearching,
              searchController: _searchController,
              onToggleSearch: _toggleSearch,
            ),
            const SizedBox(height: 10),
            _buildTabSelector(context),
            const SizedBox(height: 10),
            Expanded(child: _buildBody(context, currentUser)),
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
        return const SizedBox();
    }
  }

  // ===========================================================================
  // RESPONSIVE LIST BUILDER (CORE LOGIC)
  // ===========================================================================

  /// A reusable builder that decides between List (Mobile) and Grid (Desktop)
  /// and handles the Header + RefreshIndicator logic.
  Widget _buildResponsiveList({
    required BuildContext context,
    required List<dynamic> items,
    required dynamic user,
    required String emptyMessage,
  }) {
    // Empty State
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Center(child: Text(emptyMessage)),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Define breakpoints
        final width = constraints.maxWidth;
        bool isDesktop = width > 700; // Breakpoint for switching to grid

        // Calculate Grid Columns based on width
        int crossAxisCount = 1;
        if (width > 1300) {
          crossAxisCount = 4;
        } else if (width > 1000) {
          crossAxisCount = 3;
        } else if (width > 700) {
          crossAxisCount = 2;
        }

        return RefreshIndicator(
          onRefresh: _onRefresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // 1. The Header (Suggestions) - Spans full width
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: _buildSuggestedHeader(context, user),
                ),
              ),

              // 2. The Content (Grid or List)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 140),
                sliver: isDesktop
                    ? SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          // Adjust ratio based on your Card design.
                          // 1.4 looks like the screenshot (wider than tall)
                          childAspectRatio: 1.2,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildItem(items[index]),
                          childCount: items.length,
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _buildItem(items[index]),
                          ),
                          childCount: items.length,
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Helper to render individual items safely
  Widget _buildItem(dynamic item) {
    if (item is ChatRoom) return RoomCard(room: item);
    if (item is Tutor) return TutorCard(tutor: item);
    return const SizedBox.shrink();
  }

  // ===========================================================================
  // DATA FETCHING WRAPPERS
  // ===========================================================================

  Widget _buildMixedList(dynamic user) {
    return BlocBuilder<RoomBloc, RoomState>(
      builder: (context, roomState) {
        return BlocBuilder<TutorBloc, TutorState>(
          builder: (context, tutorState) {
            // Loading State
            if (roomState.status == RoomStatus.loading &&
                tutorState.status == TutorStatus.loading &&
                roomState.allRooms.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            // Merge & Sort
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

            return _buildResponsiveList(
              context: context,
              items: feedItems,
              user: user,
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
          return const Center(child: CircularProgressIndicator());
        }

        return _buildResponsiveList(
          context: context,
          items: state.filteredTutors,
          user: user,
          emptyMessage: "No tutors found.",
        );
      },
    );
  }

  Widget _buildRoomList(dynamic user) {
    return BlocBuilder<RoomBloc, RoomState>(
      builder: (context, state) {
        if (state.status == RoomStatus.loading && state.allRooms.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        return _buildResponsiveList(
          context: context,
          items: state.filteredRooms,
          user: user,
          emptyMessage: "No active rooms.",
        );
      },
    );
  }

  // ===========================================================================
  // REST OF UI (Tabs, FAB, Header, etc.)
  // ===========================================================================

  Widget _buildSuggestedHeader(BuildContext context, dynamic user) {
    String titleText = "Popular suggestions";
    if (user != null) {
      titleText =
          "${LanguageHelper.getLanguageName(user.currentLanguage)} suggestions";
    }

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

        String getLabel(String category, String defaultName) {
          if (roomFilters.containsKey(category)) return roomFilters[category]!;
          if (tutorFilters.containsKey(category))
            return tutorFilters[category]!;
          return defaultName;
        }

        bool isActive(String category) {
          return roomFilters.containsKey(category) ||
              tutorFilters.containsKey(category);
        }

        return SingleChildScrollView(
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
                label: getLabel('Language Level', 'Level'),
                isFilter: true,
                isSelected: isActive('Language Level'),
                onTap: () => _showFilterSheet(context, 'Language Level', [
                  'Beginner',
                  'Intermediate',
                  'Advanced',
                  'Native',
                ]),
              ),
              const SizedBox(width: 8),
              if (_currentTabIndex != 1) ...[
                TabChip(
                  label: getLabel('Paid', 'Paid'),
                  isFilter: true,
                  isSelected: isActive('Paid'),
                  onTap: () =>
                      _showFilterSheet(context, 'Paid', ['Free', 'Paid']),
                ),
                const SizedBox(width: 8),
              ],
              if (_currentTabIndex != 2) ...[
                TabChip(
                  label: getLabel('Specialty', 'Specialty'),
                  isFilter: true,
                  isSelected: isActive('Specialty'),
                  onTap: () => _showFilterSheet(context, 'Specialty', [
                    'IELTS',
                    'Business',
                    'Conversation',
                    'Grammar',
                  ]),
                ),
              ],
            ],
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

    if (_currentTabIndex == 1) {
      currentVal = tutorBloc.state.filters[category];
    } else {
      currentVal = roomBloc.state.filters[category];
    }

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
          } else if (_currentTabIndex == 1) {
            tutorBloc.add(FilterTutors(val, category: category));
          } else {
            roomBloc.add(FilterRooms(val, category: category));
          }
        },
      ),
    );
  }

  Widget _buildFab(BuildContext context, dynamic currentUser) {
    final theme = Theme.of(context);

    return BlocBuilder<RoomBloc, RoomState>(
      builder: (context, state) {
        final isInRoom = state.activeChatRoom != null;

        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton(
              heroTag: 'create',
              backgroundColor: theme.cardColor.withOpacity(0.9),
              onPressed: () {
                AuthGuard.run(
                  context,
                  onAuthenticated: () {
                    _showCreateOptions(context);
                  },
                );
              },
              child: const Icon(Icons.add_rounded, size: 32),
            ),

            if (currentUser != null) ...[
              const SizedBox(height: 16),
              FloatingActionButton(
                heroTag: 'msg',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const InboxScreen(),
                    ),
                  );
                },
                child: StreamBuilder<List<PrivateConversation>>(
                  stream: PrivateChatService().getInbox(currentUser.id),
                  builder: (context, snapshot) {
                    int totalUnreadMessages = 0;

                    if (snapshot.hasData) {
                      final chats = snapshot.data!;
                      for (var chat in chats) {
                        bool isLastMsgFromMe =
                            chat.lastSenderId == currentUser.id;
                        if (!isLastMsgFromMe) {
                          totalUnreadMessages += chat.unreadCount;
                        }
                      }
                    }

                    return Badge(
                      isLabelVisible: totalUnreadMessages > 0,
                      label: Text(
                        totalUnreadMessages > 99
                            ? '99+'
                            : '$totalUnreadMessages',
                      ),
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
                subtitle: const Text("Host a conversation for others to join"),
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
                subtitle: const Text("Offer paid lessons and coaching"),
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
