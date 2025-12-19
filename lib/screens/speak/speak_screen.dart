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

class SpeakView extends StatelessWidget {
  const SpeakView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = context.watch<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return const SizedBox();

    final user = authState.user;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,

      // --- Floating Action Buttons ---
      floatingActionButton: BlocBuilder<SpeakBloc, SpeakState>(
        builder: (context, state) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Create Button
              FloatingActionButton(
                heroTag: 'create_fab',
                backgroundColor: theme.cardColor,
                foregroundColor: theme.primaryColor,
                elevation: 4,
                onPressed: () =>
                    _showCreateOptions(context), // Logic updated below
                child: const Icon(Icons.add_rounded, size: 32),
              ),
              const SizedBox(height: 16),
              // Message Button
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
                child: Icon(
                  state.activeRoom != null
                      ? Icons.chat_bubble_outline_rounded
                      : Icons.message_rounded,
                ),
              ),
            ],
          );
        },
      ),

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
                        onPressed: () =>
                            context.read<SpeakBloc>().add(LoadSpeakData()),
                        child: const Text("Failed to load. Retry?"),
                      ),
                    );
                  }

                  switch (state.currentTab) {
                    case SpeakTab.all:
                      return _buildMixedRecommendationList(
                        context,
                        state,
                        user,
                      );
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

  // --- UPDATED: Pass Bloc to Bottom Sheets ---

  void _showCreateOptions(BuildContext context) {
    // Capture the Bloc instance from the current context
    final speakBloc = context.read<SpeakBloc>();

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                    "Create New",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.green.withOpacity(0.1),
                    child: const Icon(
                      FontAwesomeIcons.microphone,
                      color: Colors.green,
                    ),
                  ),
                  title: const Text("Start Live Room"),
                  subtitle: const Text(
                    "Host a conversation for others to join",
                  ),
                  onTap: () {
                    Navigator.pop(ctx); // Close menu

                    // Open Create Sheet with BLOC PROVIDER VALUE
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => BlocProvider.value(
                        value: speakBloc, // <--- CRITICAL FIX
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
                    ),
                  ),
                  title: const Text("Create Tutor Profile"),
                  subtitle: const Text("Offer paid lessons and coaching"),
                  onTap: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Tutor onboarding coming soon!"),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showRoomChat(BuildContext context, dynamic room) {
    // Also wrap chat in provider if it needs to access state
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RoomChatSheet(room: room),
    );
  }

  // --- Lists ---

  Widget _buildMixedRecommendationList(
    BuildContext context,
    SpeakState state,
    user,
  ) {
    // Combine lists
    final List<dynamic> feedItems = [];
    feedItems.addAll(state.rooms);
    feedItems.addAll(state.tutors);

    // Note: Calling shuffle() inside build can cause jitters if setstate is called.
    // Ideally, sort this in the Bloc. For now, we leave it but be aware.
    // feedItems.shuffle();

    if (feedItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.mic_none, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text("No active rooms yet."),
            TextButton(
              onPressed: () => _showCreateOptions(context),
              child: const Text("Start the first one!"),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
      itemCount: feedItems.length + 1, // +1 for Header
      itemBuilder: (context, index) {
        if (index == 0) {
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
                  "${LanguageHelper.getLanguageName(user.currentLanguage)} tutors & chat rooms for you",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        }

        final item = feedItems[index - 1];

        // Pass Data to Cards (Assuming you updated RoomCard/TutorCard to accept models)

        if (item is ChatRoom) {
          return RoomCard(room: item); // <--- Pass the room here
        } else if (item is Tutor) {
          return const TutorCard(); // Update TutorCard similarly if needed
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildTutorList(SpeakState state) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
      itemCount: state.tutors.length,
      itemBuilder: (context, index) => const TutorCard(), // Pass data
    );
  }

  Widget _buildRoomList(BuildContext context, SpeakState state) {
    if (state.rooms.isEmpty) {
      return const Center(child: Text("No active rooms."));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
      itemCount: state.rooms.length,
      itemBuilder: (context, index) {
        final room = state.rooms[index];
        return RoomCard(room: room); // <--- Pass the room here
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Practice Speaking',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildTabSelector(BuildContext context) {
    return BlocBuilder<SpeakBloc, SpeakState>(
      buildWhen: (previous, current) =>
          previous.currentTab != current.currentTab,
      builder: (context, state) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              _TabChip(
                label: 'All',
                icon: Icons.dashboard_rounded,
                isSelected: state.currentTab == SpeakTab.all,
                onTap: () =>
                    context.read<SpeakBloc>().add(const ChangeSpeakTab(0)),
              ),
              const SizedBox(width: 12),
              _TabChip(
                label: 'Tutors',
                icon: FontAwesomeIcons.chalkboardUser,
                isSelected: state.currentTab == SpeakTab.tutors,
                onTap: () =>
                    context.read<SpeakBloc>().add(const ChangeSpeakTab(1)),
              ),
              const SizedBox(width: 12),
              _TabChip(
                label: 'Chat Rooms',
                icon: FontAwesomeIcons.users,
                isSelected: state.currentTab == SpeakTab.rooms,
                onTap: () =>
                    context.read<SpeakBloc>().add(const ChangeSpeakTab(2)),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? theme.primaryColor : theme.cardColor,
          borderRadius: BorderRadius.circular(30),
          border: isSelected
              ? Border.all(color: theme.primaryColor)
              : Border.all(color: Colors.grey.shade300),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: theme.primaryColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : Colors.grey,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : theme.textTheme.bodyMedium?.color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
