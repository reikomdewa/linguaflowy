import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// 1. IMPORT YOUR NEW BLOCS & EVENTS
import 'package:linguaflow/blocs/speak/room/room_bloc.dart';
import 'package:linguaflow/blocs/speak/room/room_event.dart';
import 'package:linguaflow/blocs/speak/tutor/tutor_bloc.dart';
import 'package:linguaflow/blocs/speak/tutor/tutor_event.dart';

class SpeakHeader extends StatelessWidget {
  final bool isSearching;
  final TextEditingController searchController;
  final VoidCallback onToggleSearch;

  const SpeakHeader({
    super.key,
    required this.isSearching,
    required this.searchController,
    required this.onToggleSearch,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(left: 16.0, right: 16),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: isSearching
            ? TextField(
                key: const ValueKey('search_bar'),
                controller: searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search username, tutor, room...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: onToggleSearch,
                  ),
                  filled: true,
                  fillColor: theme.cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
                // 2. TRIGGER BOTH BLOCS ON CHANGE
                onChanged: (val) {
                  context.read<RoomBloc>().add(FilterRooms(val));
                  context.read<TutorBloc>().add(FilterTutors(val));
                },
              )
            : Row(
                key: const ValueKey('title_bar'),
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Practice Speaking',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.search_rounded),
                    onPressed: onToggleSearch,
                  ),
                ],
              ),
      ),
    );
  }
}
