
// ==========================================
// 🃏 REVIEW SESSION VIEW
// ==========================================
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/blocs/vocabulary/vocabulary_bloc.dart';
import 'package:linguaflow/models/vocabulary_item.dart';
import 'package:linguaflow/screens/vocabulary/widgets/flashcard_widget.dart';
import 'package:linguaflow/utils/srs_algorithm.dart';

class ReviewSessionView extends StatefulWidget {
  final List<VocabularyItem> dueItems;
  final List<VocabularyItem> allItems;

  const ReviewSessionView(
      {super.key, required this.dueItems, required this.allItems});

  @override
  _ReviewSessionViewState createState() => _ReviewSessionViewState();
}

class _ReviewSessionViewState extends State<ReviewSessionView> {
  List<VocabularyItem> _sessionQueue = [];
  bool _isSessionActive = false;
  bool _isCramMode = false;

  @override
  void initState() {
    super.initState();
    if (widget.dueItems.isNotEmpty) {
      _startSession(widget.dueItems);
    }
  }

  void _startSession(List<VocabularyItem> items, {bool cram = false}) {
    setState(() {
      _sessionQueue = List.from(items.take(20)); // Limit to 20 for session
      _isSessionActive = true;
      _isCramMode = cram;
    });
  }

  void _handleRating(int rating) {
    if (_sessionQueue.isEmpty) return;
    final currentItem = _sessionQueue[0];
    
    // Calculate next status based on rating
    final newStatus = SRSAlgorithm.nextStatus(currentItem.status, rating);
    
    final newItem = currentItem.copyWith(
      status: newStatus,
      lastReviewed: DateTime.now(),
      timesEncountered: currentItem.timesEncountered + 1,
    );
    
    context.read<VocabularyBloc>().add(VocabularyUpdateRequested(newItem));
    
    _advanceQueue();
  }

  void _handleDelete() {
    if (_sessionQueue.isEmpty) return;
    final currentItem = _sessionQueue[0];

    // ✅ Pass both ID and UserID to the Bloc Event
    context.read<VocabularyBloc>().add(
      VocabularyDeleteRequested(
        id: currentItem.id, 
        userId: currentItem.userId
      )
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Card deleted permanently")),
    );

    _advanceQueue();
  }

  void _advanceQueue() {
    setState(() {
      _sessionQueue.removeAt(0);
      if (_sessionQueue.isEmpty) {
        _isSessionActive = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isSessionActive && _sessionQueue.isNotEmpty) {
      final item = _sessionQueue.first;
      return Column(
        children: [
          _buildProgressBar(isDark),
          Expanded(
            child: Flashcard(
              key: ValueKey(item.id), // Key is crucial for Dismissible to work
              item: item,
              onRated: _handleRating,
              onDelete: _handleDelete,
            ),
          ),
        ],
      );
    }

    // --- EMPTY STATE UI ---
    final dueCount = widget.dueItems.length;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_rounded,
                size: 80, color: Colors.green[300]),
            const SizedBox(height: 24),
            Text(
              dueCount > 0 ? "Ready to Review?" : "All Caught Up!",
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              dueCount > 0
                  ? "You have $dueCount words waiting for you."
                  : "No cards are strictly due right now.",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 40),
            
            // Start Due Button
            if (dueCount > 0)
              _buildLargeButton(
                icon: Icons.play_arrow_rounded,
                label: "Start Daily Review ($dueCount)",
                color: Colors.blue,
                onTap: () => _startSession(widget.dueItems),
              ),
              
            // Cram Options
            const SizedBox(height: 16),
            if (dueCount == 0) ...[
              const Text("Want to study anyway?",
                  style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              _buildLargeButton(
                icon: Icons.bolt_rounded,
                label: "Cram Session (Random 20)",
                color: Colors.orange,
                onTap: () {
                  final mixed = List<VocabularyItem>.from(widget.allItems)
                    ..shuffle();
                  _startSession(mixed, cram: true);
                },
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(bool isDark) {
    final total = 20;
    final current = total - _sessionQueue.length;
    final pct = current / total;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_isCramMode ? "🔥 Cramming" : "📚 Daily Review",
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text("${_sessionQueue.length} left",
                  style: const TextStyle(color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct > 1.0 ? 1.0 : pct,
              minHeight: 6,
              backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLargeButton(
      {required IconData icon,
      required String label,
      required Color color,
      required VoidCallback onTap}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: Icon(icon, color: Colors.white),
        label: Text(label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 4,
        ),
      ),
    );
  }
}
