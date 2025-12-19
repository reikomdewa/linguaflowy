import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// Bloc and State imports
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/speak/speak_bloc.dart';
import 'package:linguaflow/blocs/speak/speak_event.dart';
import 'package:linguaflow/blocs/speak/speak_state.dart';

// Model and Utils imports
import 'package:linguaflow/models/speak/speak_models.dart';
import 'package:linguaflow/screens/speak/create_tutor_profile_screen.dart';
import 'package:linguaflow/screens/speak/widgets/filter_bottom_sheet.dart';
import 'package:linguaflow/screens/speak/widgets/speak_header.dart';
import 'package:linguaflow/screens/speak/widgets/tab_chip.dart';
import 'package:linguaflow/utils/language_helper.dart';

// Reusable UI components from your project structure
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
      context.read<SpeakBloc>().add(ClearAllFilters());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = context.watch<AuthBloc>().state;

    // Safety check for auth state
    if (authState is! AuthAuthenticated)
      return const Scaffold(body: SizedBox());

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
              child: BlocBuilder<SpeakBloc, SpeakState>(
                builder: (context, state) {
                  if (state.status == SpeakStatus.loading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state.status == SpeakStatus.failure) {
                    return Center(
                      child: TextButton(
                        onPressed: () =>
                            context.read<SpeakBloc>().add(LoadSpeakData()),
                        child: const Text("Retry"),
                      ),
                    );
                  }

                  switch (state.currentTab) {
                    case SpeakTab.all:
                      return _buildMixedList(context, state, authState.user);
                    case SpeakTab.tutors:
                      return _buildTutorList(state);
                    case SpeakTab.rooms:
                      return _buildRoomList(state);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSelector(BuildContext context) {
    return BlocBuilder<SpeakBloc, SpeakState>(
      builder: (context, state) {
        final isTutorContext =
            state.currentTab == SpeakTab.all ||
            state.currentTab == SpeakTab.tutors;
        String getLabel(String category, String defaultName) =>
            state.filters[category] ?? defaultName;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              TabChip(
                label: 'All',
                isSelected: state.currentTab == SpeakTab.all,
                onTap: () =>
                    context.read<SpeakBloc>().add(const ChangeSpeakTab(0)),
              ),
              const SizedBox(width: 8),
              TabChip(
                label: 'Tutors',
                isSelected: state.currentTab == SpeakTab.tutors,
                onTap: () =>
                    context.read<SpeakBloc>().add(const ChangeSpeakTab(1)),
              ),
              const SizedBox(width: 8),
              TabChip(
                label: 'Rooms',
                isSelected: state.currentTab == SpeakTab.rooms,
                onTap: () =>
                    context.read<SpeakBloc>().add(const ChangeSpeakTab(2)),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(height: 24, child: VerticalDivider(width: 1)),
              ),

              TabChip(
                label: getLabel('Language Level', 'Level'),
                isFilter: true,
                isSelected: state.filters.containsKey('Language Level'),
                onTap: () => _showFilterSheet(context, 'Language Level', [
                  'Beginner',
                  'Intermediate',
                  'Advanced',
                  'Native',
                ]),
              ),
              const SizedBox(width: 8),
              TabChip(
                label: getLabel('Paid', 'Paid'),
                isFilter: true,
                isSelected: state.filters.containsKey('Paid'),
                onTap: () =>
                    _showFilterSheet(context, 'Paid', ['Free', 'Paid']),
              ),

              if (isTutorContext) ...[
                const SizedBox(width: 8),
                TabChip(
                  label: getLabel('Specialty', 'Specialty'),
                  isFilter: true,
                  isSelected: state.filters.containsKey('Specialty'),
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
    final speakBloc = context.read<SpeakBloc>();
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => FilterBottomSheet(
        category: category,
        options: options,
        currentSelection: speakBloc.state.filters[category],
        onSelect: (val) =>
            speakBloc.add(FilterSpeakList(val, category: category)),
      ),
    );
  }

  Widget _buildMixedList(BuildContext context, SpeakState state, dynamic user) {
  final List<dynamic> feedItems = [...state.rooms, ...state.tutors];
  if (feedItems.isEmpty) return const Center(child: Text("No suggestions found."));

  return ListView.builder(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
    itemCount: feedItems.length + 1,
    itemBuilder: (context, index) {
      if (index == 0) return _buildSuggestedHeader(context, user);
      
      final item = feedItems[index - 1];
      
      // FIX: Pass the item (tutor) to the card
      return item is ChatRoom 
          ? RoomCard(room: item) 
          : TutorCard(tutor: item as Tutor); // Change this line
    },
  );
}

  Widget _buildSuggestedHeader(BuildContext context, dynamic user) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 4),
      child: Row(
        children: [
          Icon(
            Icons.auto_awesome,
            size: 18,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(width: 8),
          Text(
            "${LanguageHelper.getLanguageName(user.currentLanguage)} suggestions",
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

Widget _buildTutorList(SpeakState state) => ListView.builder(
  padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
  itemCount: state.tutors.length,
  itemBuilder: (context, index) {
    // FIX: Pass the specific tutor from the state list
    return TutorCard(tutor: state.tutors[index]); 
  },
);

  Widget _buildRoomList(SpeakState state) => ListView.builder(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
    itemCount: state.rooms.length,
    itemBuilder: (context, index) => RoomCard(room: state.rooms[index]),
  );

  // --- RESTORED LOGIC FOR FAB AND SHEETS ---

  Widget _buildFab(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<SpeakBloc, SpeakState>(
      builder: (context, state) => Column(
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
            backgroundColor: theme.primaryColor,
            foregroundColor: Colors.white,
            onPressed: () => state.activeRoom != null
                ? _showRoomChat(context, state.activeRoom!)
                : Navigator.pushNamed(context, '/global_messages'),
            child: Icon(
              state.activeRoom != null
                  ? Icons.chat_bubble_outline_rounded
                  : Icons.message_rounded,
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateOptions(BuildContext context) {
    final speakBloc = context.read<SpeakBloc>();
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
                      value: speakBloc,
                      child: const CreateRoomSheet(),
                    ),
                  );
                },
              ),
              ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue.withOpacity(0.1), 
                child: const Icon(FontAwesomeIcons.chalkboardUser, color: Colors.blue, size: 20)
              ),
              title: const Text("Create Tutor Profile"),
              subtitle: const Text("Offer paid lessons and coaching"),
              onTap: () {
                Navigator.pop(ctx); // Close the bottom sheet
                // Navigate to the new screen
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

  void _showRoomChat(BuildContext context, dynamic room) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RoomChatSheet(room: room),
    );
  }
}
