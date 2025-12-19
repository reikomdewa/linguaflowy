import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/speak/speak_bloc.dart';
import 'package:linguaflow/blocs/speak/speak_event.dart';
import 'package:linguaflow/blocs/speak/speak_state.dart';
import 'package:linguaflow/models/speak_models.dart';
import 'package:linguaflow/screens/speak/widgets/sheets/create_room_sheet.dart';
import 'package:linguaflow/screens/speak/widgets/cards/room_card.dart';
import 'package:linguaflow/screens/speak/widgets/sheets/room_chat_sheet.dart';
import 'package:linguaflow/screens/speak/widgets/cards/tutor_card.dart';
import 'package:linguaflow/utils/language_helper.dart';

class SpeakScreen extends StatelessWidget {
  const SpeakScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => SpeakBloc()..add(LoadSpeakData()),
      child: const SpeakView(),
    );
  }
}

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = context.watch<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return const SizedBox();

    final user = authState.user;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton: _buildFab(context),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
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
                        onPressed: () => context.read<SpeakBloc>().add(LoadSpeakData()),
                        child: const Text("Failed to load. Retry?"),
                      ),
                    );
                  }

                  switch (state.currentTab) {
                    case SpeakTab.all:
                      return _buildMixedRecommendationList(context, state, user);
                    case SpeakTab.tutors:
                      return _buildTutorList(state);
                    case SpeakTab.rooms:
                      return _buildRoomList(context, state);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- RESTORED Header with Search Feature ---
  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _isSearching
            ? TextField(
                key: const ValueKey('search_bar'),
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search username, tutor, room, price...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      setState(() => _isSearching = false);
                      _searchController.clear();
                      context.read<SpeakBloc>().add(ClearAllFilters());
                    },
                  ),
                  filled: true,
                  fillColor: theme.cardColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (val) => context.read<SpeakBloc>().add(FilterSpeakList(val)),
              )
            : Row(
                key: const ValueKey('title_bar'),
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Practice Speaking',
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.search_rounded),
                        onPressed: () => setState(() => _isSearching = true),
                      ),
                      IconButton(
                        icon: const Icon(Icons.filter_list_rounded),
                        onPressed: () {}, // Optional: opens global filter
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  // --- Tabs + RESTORED Dynamic Filter Chips ---
  Widget _buildTabSelector(BuildContext context) {
    return BlocBuilder<SpeakBloc, SpeakState>(
      builder: (context, state) {
        final isTutorContext = state.currentTab == SpeakTab.all || state.currentTab == SpeakTab.tutors;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _TabChip(label: 'All', isSelected: state.currentTab == SpeakTab.all, onTap: () => context.read<SpeakBloc>().add(const ChangeSpeakTab(0))),
              const SizedBox(width: 8),
              _TabChip(label: 'Tutors', isSelected: state.currentTab == SpeakTab.tutors, onTap: () => context.read<SpeakBloc>().add(const ChangeSpeakTab(1))),
              const SizedBox(width: 8),
              _TabChip(label: 'Rooms', isSelected: state.currentTab == SpeakTab.rooms, onTap: () => context.read<SpeakBloc>().add(const ChangeSpeakTab(2))),
              
              const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: VerticalDivider(width: 1)),

              _TabChip(label: 'Language Level', isFilter: true, onTap: () => _showFilterSheet(context, 'Language Level', ['Beginner', 'Intermediate', 'Advanced', 'Native'])),
              const SizedBox(width: 8),
              _TabChip(label: 'Paid', isFilter: true, onTap: () => _showFilterSheet(context, 'Paid', ['Free', 'Paid'])),
              
              if (isTutorContext) ...[
                const SizedBox(width: 8),
                _TabChip(label: 'Specialty', isFilter: true, onTap: () => _showFilterSheet(context, 'Specialty', ['IELTS', 'Business', 'Conversation', 'Grammar'])),
                const SizedBox(width: 8),
                _TabChip(label: 'Country of Birth', isFilter: true, onTap: () => _showFilterSheet(context, 'Country of Birth', ['USA', 'UK', 'Canada', 'Australia'])),
              ],
              
              const SizedBox(width: 8),
              _TabChip(label: 'Availability', isFilter: true, onTap: () => _showFilterSheet(context, 'Availability', ['Available Now', 'Today', 'This Week'])),
            ],
          ),
        );
      },
    );
  }

  void _showFilterSheet(BuildContext context, String category, List<String> options) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Select $category", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12, runSpacing: 12,
              children: options.map((opt) => ActionChip(
                label: Text(opt),
                onPressed: () {
                  context.read<SpeakBloc>().add(FilterSpeakList(opt, category: category));
                  Navigator.pop(ctx);
                },
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // --- RESTORED Mixed List with Suggested Header ---
  Widget _buildMixedRecommendationList(BuildContext context, SpeakState state, dynamic user) {
    final List<dynamic> feedItems = [...state.rooms, ...state.tutors];
    if (feedItems.isEmpty) return const Center(child: Text("No suggestions found."));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
      itemCount: feedItems.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16, left: 4),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, size: 18, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  "${LanguageHelper.getLanguageName(user.currentLanguage)} tutors & chat rooms for you",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          );
        }
        final item = feedItems[index - 1];
        return item is ChatRoom ? RoomCard(room: item) : const TutorCard();
      },
    );
  }

  Widget _buildTutorList(SpeakState state) => ListView.builder(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
    itemCount: state.tutors.length,
    itemBuilder: (context, index) => const TutorCard(),
  );

  Widget _buildRoomList(BuildContext context, SpeakState state) => ListView.builder(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
    itemCount: state.rooms.length,
    itemBuilder: (context, index) => RoomCard(room: state.rooms[index]),
  );

  // --- RESTORED Creation Bottom Sheet with Full Descriptions ---
  void _showCreateOptions(BuildContext context) {
    final speakBloc = context.read<SpeakBloc>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text("Create New", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ),
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
                    isScrollControlled: true,
                    builder: (_) => BlocProvider.value(value: speakBloc, child: const CreateRoomSheet()),
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
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- RESTORED Floating Action Buttons ---
  Widget _buildFab(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<SpeakBloc, SpeakState>(
      builder: (context, state) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton(
              heroTag: 'create_fab',
              backgroundColor: theme.cardColor.withOpacity(0.9),
              elevation: 4,
              onPressed: () => _showCreateOptions(context),
              child: const Icon(Icons.add_rounded, size: 32),
            ),
            const SizedBox(height: 16),
            FloatingActionButton(
              heroTag: 'msg_fab',
              backgroundColor: theme.primaryColor,
              foregroundColor: Colors.white,
              onPressed: () {
                if (state.activeRoom != null) {
                  _showRoomChat(context, state.activeRoom!);
                } else {
                  Navigator.pushNamed(context, '/global_messages');
                }
              },
              child: Icon(state.activeRoom != null ? Icons.chat_bubble_outline_rounded : Icons.message_rounded),
            ),
          ],
        );
      },
    );
  }

  void _showRoomChat(BuildContext context, dynamic room) {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => RoomChatSheet(room: room));
  }
}

// --- Theme-Aware Pill Chip ---
class _TabChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isFilter;
  final VoidCallback onTap;

  const _TabChip({required this.label, this.isSelected = false, this.isFilter = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color selectedBg = isDark ? Colors.white : theme.primaryColor;
    final Color unselectedBg = isDark ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.05);

    final Color selectedText = isDark ? Colors.black : Colors.white;
    final Color unselectedText = isDark ? Colors.white.withOpacity(0.9) : Colors.black.withOpacity(0.7);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        decoration: BoxDecoration(color: isSelected ? selectedBg : unselectedBg, borderRadius: BorderRadius.circular(100)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(color: isSelected ? selectedText : unselectedText, fontWeight: FontWeight.w600, fontSize: 14)),
            if (isFilter) ...[
              const SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: isSelected ? selectedText.withOpacity(0.7) : unselectedText.withOpacity(0.5)),
            ],
          ],
        ),
      ),
    );
  }
}