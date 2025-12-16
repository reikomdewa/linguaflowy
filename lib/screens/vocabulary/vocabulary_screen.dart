import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/vocabulary/vocabulary_bloc.dart';
import 'package:linguaflow/screens/vocabulary/views/library_view.dart';
import 'package:linguaflow/screens/vocabulary/views/review_session_view.dart';
import 'package:linguaflow/utils/srs_algorithm.dart';

// Import split widgets

class VocabularyScreen extends StatefulWidget {
  const VocabularyScreen({super.key});
  @override
  State<VocabularyScreen> createState() => _VocabularyScreenState();
}

class _VocabularyScreenState extends State<VocabularyScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Load vocabulary on init
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      context.read<VocabularyBloc>().add(VocabularyLoadRequested(authState.user.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF121212) : Colors.grey[100];

    // 1. Get Current Language directly from Auth User
    final authState = context.watch<AuthBloc>().state;
    String targetLanguage = '';
    
    if (authState is AuthAuthenticated) {
      // FIXED: Using 'currentLanguage' per your model
      targetLanguage = authState.user.currentLanguage;
    } else {
      // Safety fallback if something is wrong with auth
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

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
            // 2. FILTER items by authState.user.currentLanguage
            final languageItems = state.items
                .where((item) => item.language == targetLanguage)
                .toList();

            // 3. Calculate Due Items from the filtered list
            final dueItems = languageItems.where((i) => SRSAlgorithm.isDue(i)).toList();
            dueItems.sort((a, b) => a.status.compareTo(b.status));

            // Empty State for specific language
            if (languageItems.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.translate, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      "No words saved for this language yet.",
                      style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Target Language: ${targetLanguage.toUpperCase()}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }

            return TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                // Pass the FILTERED lists to the views
                ReviewSessionView(dueItems: dueItems, allItems: languageItems),
                LibraryView(items: languageItems),
              ],
            );
          }
          return const Center(child: Text("Initializing..."));
        },
      ),
    );
  }
}