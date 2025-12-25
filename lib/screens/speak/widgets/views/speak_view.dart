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
import 'package:livekit_client/livekit_client.dart'; // <--- 1. ADDED THIS IMPORT



// Model and Utils imports
import 'package:linguaflow/models/speak/speak_models.dart'; // Barrel file
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
      // Clear filters on BOTH blocs
      context.read<RoomBloc>().add(const FilterRooms(null));
      context.read<TutorBloc>().add(const FilterTutors(null));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = context.watch<AuthBloc>().state;

    if (authState is! AuthAuthenticated) return const Scaffold(body: SizedBox());

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton: _buildFab(context),
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
            Expanded(
              child: _buildBody(context, authState.user),
            ),
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
        return _buildTutorList();    
      case 2:
        return _buildRoomList();      
      default:
        return const SizedBox();
    }
  }

  // ===========================================================================
  // TABS & FILTERS
  // ===========================================================================
  Widget _buildTabSelector(BuildContext context) {
    return Builder(
      builder: (context) {
        final roomFilters = context.watch<RoomBloc>().state.filters;
        final tutorFilters = context.watch<TutorBloc>().state.filters;

        String getLabel(String category, String defaultName) {
           if (roomFilters.containsKey(category)) return roomFilters[category]!;
           if (tutorFilters.containsKey(category)) return tutorFilters[category]!;
           return defaultName;
        }
        
        bool isActive(String category) {
          return roomFilters.containsKey(category) || tutorFilters.containsKey(category);
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
                  'Beginner', 'Intermediate', 'Advanced', 'Native',
                ]),
              ),
              const SizedBox(width: 8),
              if (_currentTabIndex != 1) ...[ 
                TabChip(
                  label: getLabel('Paid', 'Paid'),
                  isFilter: true,
                  isSelected: isActive('Paid'),
                  onTap: () => _showFilterSheet(context, 'Paid', ['Free', 'Paid']),
                ),
                const SizedBox(width: 8),
              ],
              if (_currentTabIndex != 2) ...[
                TabChip(
                  label: getLabel('Specialty', 'Specialty'),
                  isFilter: true,
                  isSelected: isActive('Specialty'),
                  onTap: () => _showFilterSheet(context, 'Specialty', [
                    'IELTS', 'Business', 'Conversation', 'Grammar',
                  ]),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showFilterSheet(BuildContext context, String category, List<String> options) {
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

  // ===========================================================================
  // LIST BUILDERS
  // ===========================================================================

  Widget _buildMixedList(dynamic user) {
    return BlocBuilder<RoomBloc, RoomState>(
      builder: (context, roomState) {
        return BlocBuilder<TutorBloc, TutorState>(
          builder: (context, tutorState) {
            
            if (roomState.status == RoomStatus.loading && 
                tutorState.status == TutorStatus.loading && 
                roomState.allRooms.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            final List<dynamic> feedItems = [
              ...roomState.filteredRooms, 
              ...tutorState.filteredTutors
            ];

            feedItems.sort((a, b) {
              DateTime dateA = (a is ChatRoom) ? a.createdAt : (a as Tutor).createdAt;
              DateTime dateB = (b is ChatRoom) ? b.createdAt : (b as Tutor).createdAt;
              return dateB.compareTo(dateA);
            });

            if (feedItems.isEmpty) {
               return const Center(child: Text("No suggestions found."));
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
              itemCount: feedItems.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) return _buildSuggestedHeader(context, user);
                final item = feedItems[index - 1];

                if (item is ChatRoom) return RoomCard(room: item);
                return TutorCard(tutor: item as Tutor);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildTutorList() {
    return BlocBuilder<TutorBloc, TutorState>(
      builder: (context, state) {
        if (state.status == TutorStatus.loading && state.allTutors.isEmpty) {
           return const Center(child: CircularProgressIndicator());
        }
        if (state.filteredTutors.isEmpty) {
           return const Center(child: Text("No tutors found"));
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
          itemCount: state.filteredTutors.length,
          itemBuilder: (context, index) => TutorCard(tutor: state.filteredTutors[index]),
        );
      },
    );
  }

  Widget _buildRoomList() {
    return BlocBuilder<RoomBloc, RoomState>(
      builder: (context, state) {
        if (state.status == RoomStatus.loading && state.allRooms.isEmpty) {
           return const Center(child: CircularProgressIndicator());
        }
        if (state.filteredRooms.isEmpty) {
           return const Center(child: Text("No active rooms"));
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
          itemCount: state.filteredRooms.length,
          itemBuilder: (context, index) => RoomCard(room: state.filteredRooms[index]),
        );
      },
    );
  }

  Widget _buildSuggestedHeader(BuildContext context, dynamic user) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 4),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, size: 18, color: Theme.of(context).primaryColor),
          const SizedBox(width: 8),
          Text(
            "${LanguageHelper.getLanguageName(user.currentLanguage)} suggestions",
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // FAB & ACTIONS
  // ===========================================================================
Widget _buildFab(BuildContext context) {
    final theme = Theme.of(context);
    final authState = context.read<AuthBloc>().state;

    // Guard: If not authenticated, return empty or standard fab
    if (authState is! AuthAuthenticated) return const SizedBox();

    final currentUser = authState.user;

    // Listen to RoomBloc to see if we are in a room
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
              onPressed: () => _showCreateOptions(context),
              child: const Icon(Icons.add_rounded, size: 32),
            ),
            const SizedBox(height: 16),
            
            FloatingActionButton(
              heroTag: 'msg',
              backgroundColor: theme.primaryColor, // Use primary color for main action
              foregroundColor: Colors.white, // Ensure icon is visible
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const InboxScreen()),
                );
              },
              // Wrap the Icon in a StreamBuilder to get real-time data
              child: StreamBuilder<List<PrivateConversation>>(
                stream: PrivateChatService().getInbox(currentUser.id),
                builder: (context, snapshot) {
                  int unreadCount = 0;

                  if (snapshot.hasData) {
                    final chats = snapshot.data!;
                    
                    // LOGIC: Count chats that are unread.
                    // Note: This assumes your PrivateConversation model has 'isRead' 
                    // and 'lastSenderId'. If not, it defaults to 0 to prevent errors.
                    // You can simple return chats.length to test if you don't have those fields yet.
                    unreadCount = chats.where((chat) {
                      // Attempt to check if unread (Safely handling dynamic/missing fields)
                      final data = chat as dynamic; 
                      
                      // Example Logic: If I am NOT the last sender, and it is NOT read
                      try {
                        bool isLastMsgFromMe = data.lastSenderId == currentUser.id;
                        bool isRead = data.isRead ?? true; 
                        return !isLastMsgFromMe && !isRead;
                      } catch (e) {
                        return false; // Fail safe
                      }
                    }).length;
                  }

                  return Badge(
                    isLabelVisible: unreadCount > 0,
                    label: Text(unreadCount > 99 ? '99+' : '$unreadCount'),
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    offset: const Offset(4, -4), // Adjust badge position
                    child: Icon(
                      isInRoom
                          ? Icons.chat_bubble_outline_rounded
                          : Icons.message_rounded,
                      size: 24,
                    ),
                  );
                },
              ),
            ),
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
                  child: const Icon(FontAwesomeIcons.microphone, color: Colors.green, size: 20),
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
                  child: const Icon(FontAwesomeIcons.chalkboardUser, color: Colors.blue, size: 20),
                ),
                title: const Text("Create Tutor Profile"),
                subtitle: const Text("Offer paid lessons and coaching"),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CreateTutorProfileScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 3. UPDATED SIGNATURE: Accepts LiveKit Room
  void _showRoomChat(BuildContext context, Room room) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RoomChatSheet(room: room),
    );
  }
}