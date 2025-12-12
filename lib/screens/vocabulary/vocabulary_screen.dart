import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/vocabulary/vocabulary_bloc.dart';
import 'package:linguaflow/models/vocabulary_item.dart';
import 'package:linguaflow/screens/vocabulary/views/library_view.dart';
import 'package:linguaflow/screens/vocabulary/views/review_session_view.dart';
import 'package:linguaflow/utils/srs_algorithm.dart';

// Import split widgets
import 'widgets/flashcard_widget.dart';

// You can also put ReviewSessionView and LibraryView in their own files if preferred, 
// but sticking to the 4-file structure for now.

class VocabularyScreen extends StatefulWidget {
  const VocabularyScreen({super.key});
  @override
  _VocabularyScreenState createState() => _VocabularyScreenState();
}

class _VocabularyScreenState extends State<VocabularyScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      context.read<VocabularyBloc>().add(VocabularyLoadRequested(authState.user.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF121212) : Colors.grey[100];

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Smart Flashcards', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blueAccent,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blueAccent,
          tabs: const [Tab(text: "Review Deck"), Tab(text: "All Words")],
        ),
      ),
      body: BlocBuilder<VocabularyBloc, VocabularyState>(
        builder: (context, state) {
          if (state is VocabularyLoading) return const Center(child: CircularProgressIndicator());
          if (state is VocabularyError) return Center(child: Text("Error: ${state.message}"));

          if (state is VocabularyLoaded) {
            final dueItems = state.items.where((i) => SRSAlgorithm.isDue(i)).toList();
            dueItems.sort((a, b) => a.status.compareTo(b.status));

            return TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                ReviewSessionView(dueItems: dueItems, allItems: state.items),
                LibraryView(items: state.items),
              ],
            );
          }
          return const Center(child: Text("Initializing..."));
        },
      ),
    );
  }
}

// ... Include ReviewSessionView and LibraryView classes from previous code here 
// ... OR extract them to lib/screens/vocabulary/views/ if you want total separation.
// For the sake of this answer, assume they are pasted here or imported.