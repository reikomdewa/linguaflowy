import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:math' as math;

// Import your existing project files
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/vocabulary/vocabulary_bloc.dart';
import 'package:linguaflow/models/vocabulary_item.dart';
import 'package:linguaflow/services/mymemory_service.dart';
import 'package:linguaflow/services/translation_service.dart'; 
import 'package:linguaflow/utils/language_helper.dart'; 

// ==========================================
// 🧠 SRS ALGORITHM (The Brain)
// ==========================================
class SRSAlgorithm {
  // Returns true if the word should be reviewed today
  static bool isDue(VocabularyItem item) {
    if (item.status == 0) return true; // New words always due
    final now = DateTime.now();
    final difference = now.difference(item.lastReviewed).inDays;

    // Mapping Status (0-5) to Days required before next review
    int requiredGap;
    switch (item.status) {
      case 1: requiredGap = 0; break; 
      case 2: requiredGap = 2; break;
      case 3: requiredGap = 6; break;
      case 4: requiredGap = 13; break;
      case 5: requiredGap = 29; break;
      default: requiredGap = 0;
    }
    return difference >= requiredGap;
  }

  // Calculate Next Status based on Button Press
  static int nextStatus(int current, int rating) {
    // Rating: 1=Again, 2=Hard, 3=Good, 4=Easy
    if (rating == 1) return 1; // Forgot? Reset to 1.
    if (rating == 2) return current > 1 ? current : 1; // Hard? Don't advance.
    if (rating == 3) return math.min(current + 1, 5); // Good? Advance.
    if (rating == 4) return math.min(current + 2, 5); // Easy? Jump.
    return current;
  }

  // Helper text to show user when they will see the card again
  static String getNextIntervalText(int currentStatus, int rating) {
    int next = nextStatus(currentStatus, rating);
    if (next == 1) return "1d";
    if (next == 2) return "3d";
    if (next == 3) return "7d";
    if (next == 4) return "14d";
    if (next == 5) return "30d";
    return "1d";
  }
}

// ==========================================
// 📱 MAIN SCREEN
// ==========================================
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
    
    // Safety check to ensure Auth is authenticated before accessing user
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
        title: const Text('Smart Flashcards',
            style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blueAccent,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blueAccent,
          tabs: const [
            Tab(text: "Review Deck"),
            Tab(text: "All Words"),
          ],
        ),
      ),
      body: BlocBuilder<VocabularyBloc, VocabularyState>(
        builder: (context, state) {
          if (state is VocabularyLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is VocabularyLoaded) {
            // Filter due items
            final dueItems =
                state.items.where((i) => SRSAlgorithm.isDue(i)).toList();
            // Sort due items: Newest/Lowest Status first
            dueItems.sort((a, b) => a.status.compareTo(b.status));

            return TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                ReviewSessionView(
                  dueItems: dueItems,
                  allItems: state.items,
                ),
                LibraryView(items: state.items),
              ],
            );
          }
          
          if (state is VocabularyError) {
             return Center(child: Text("Error: ${state.message}"));
          }
          
          return const Center(child: Text("Initializing..."));
        },
      ),
    );
  }
}

// ==========================================
// 🃏 REVIEW SESSION VIEW
// ==========================================
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

// ==========================================
// 💳 FLASHCARD WIDGET (Swipe, Delete, Buttons & Translation)
// ==========================================
class Flashcard extends StatefulWidget {
  final VocabularyItem item;
  final Function(int) onRated;
  final VoidCallback onDelete;

  const Flashcard({
    super.key, 
    required this.item, 
    required this.onRated,
    required this.onDelete,
  });

  @override
  _FlashcardState createState() => _FlashcardState();
}

class _FlashcardState extends State<Flashcard>
    with SingleTickerProviderStateMixin {
  bool _isRevealed = false;
  late AnimationController _controller;
  late Animation<double> _animation;

  // Translation State
  String? _myMemoryTranslation;
  String? _googleTranslation;
  bool _isLoadingExtra = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _animation = Tween<double>(begin: 0, end: 1).animate(_controller);
  }

  void _flip() {
    setState(() => _isRevealed = true);
    _controller.forward();
    _fetchAlternativeTranslations();
  }

  Future<void> _fetchAlternativeTranslations() async {
    if (_isLoadingExtra) return;

    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;
    final user = authState.user;
    
    setState(() => _isLoadingExtra = true);

    String? mmResult;
    String? googleResult;

    // Fetch MyMemory
    try {
      mmResult = await MyMemoryService.translate(
        text: widget.item.word,
        sourceLang: widget.item.language,
        targetLang: user.nativeLanguage,
      );
    } catch (_) {}

    // Fetch Google
    try {
      final service = context.read<TranslationService>();
      googleResult = await service.translate(
        widget.item.word,
        user.nativeLanguage,
        widget.item.language,
      );
    } catch (_) {}

    if (mounted) {
      setState(() {
        _myMemoryTranslation = mmResult;
        _googleTranslation = googleResult;
        _isLoadingExtra = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF2C2C2C) : Colors.white;
    final txtColor = isDark ? Colors.white : Colors.black87;

    // --- SWIPE LOGIC WRAPPER ---
    return Dismissible(
      key: ValueKey(widget.item.id),
      direction: DismissDirection.horizontal, // Allow Left and Right Swipe
      
      // Swipe Right -> Mark as Good (Green)
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
        decoration: BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 30),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.thumb_up_alt_rounded, color: Colors.white, size: 40),
            Text("Good", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
          ],
        ),
      ),
      
      // Swipe Left -> Mark as Again (Red)
      secondaryBackground: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
        decoration: BoxDecoration(
          color: Colors.orange,
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 30),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.refresh_rounded, color: Colors.white, size: 40),
            Text("Again", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
          ],
        ),
      ),
      
      onDismissed: (direction) {
        if (direction == DismissDirection.startToEnd) {
          // Swipe Right: Mark as GOOD (3)
          widget.onRated(3);
        } else {
          // Swipe Left: Mark as AGAIN (1)
          widget.onRated(1);
        }
      },
      
      child: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _isRevealed ? null : _flip,
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Status Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getStatusColor(widget.item.status).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _getStatusLabel(widget.item.status).toUpperCase(),
                            style: TextStyle(
                                color: _getStatusColor(widget.item.status),
                                fontWeight: FontWeight.bold,
                                fontSize: 10),
                          ),
                        ),
                        const Spacer(),

                        // FRONT (Word)
                        Text(
                          widget.item.word,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: txtColor),
                        ),

                        const SizedBox(height: 20),

                        // BACK (Translations + Extra)
                        FadeTransition(
                          opacity: _animation,
                          child: Column(
                            children: [
                              Divider(color: Colors.grey.withOpacity(0.3)),
                              const SizedBox(height: 10),
                              
                              Text(
                                widget.item.translation,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 24,
                                    color: Colors.blueAccent,
                                    fontWeight: FontWeight.w500),
                              ),

                              if (widget.item.notes != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 10.0),
                                  child: Text(
                                    widget.item.notes!,
                                    style: const TextStyle(
                                        color: Colors.grey, fontStyle: FontStyle.italic),
                                  ),
                                ),

                              if (_isRevealed) ...[
                                const SizedBox(height: 20),
                                if (_isLoadingExtra)
                                  const SizedBox(
                                    height: 15, width: 15,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                else
                                  Column(
                                    children: [
                                      if (_myMemoryTranslation != null && 
                                          _myMemoryTranslation != widget.item.translation)
                                        _buildAltTranslationRow(
                                            "MyMemory", _myMemoryTranslation!, isDark),
                                      
                                      if (_googleTranslation != null && 
                                          _googleTranslation != widget.item.translation &&
                                          _googleTranslation != _myMemoryTranslation)
                                        _buildAltTranslationRow(
                                            "Google", _googleTranslation!, isDark),
                                    ],
                                  ),
                              ]
                            ],
                          ),
                        ),
                        const Spacer(),
                        if (!_isRevealed)
                          Text("Tap to flip",
                              style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                      ],
                    ),
                  ),

                  // --- MENU BUTTON FOR DELETE ---
                  Positioned(
                    top: 10,
                    right: 30,
                    child: PopupMenuButton<String>(
                      icon: Icon(Icons.more_horiz, color: Colors.grey[400]),
                      onSelected: (value) {
                        if (value == 'delete') {
                          _showDeleteConfirm();
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, color: Colors.red),
                              SizedBox(width: 8),
                              Text("Delete Card", style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- ANKI BUTTONS AREA (Restored!) ---
          const SizedBox(height: 20),
          SizedBox(
            height: 100, // Fixed height for buttons
            child: _isRevealed
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildRatingBtn("Again", Colors.red, 1),
                        _buildRatingBtn("Hard", Colors.orange, 2),
                        _buildRatingBtn("Good", Colors.blue, 3),
                        _buildRatingBtn("Easy", Colors.green, 4),
                      ],
                    ),
                  )
                : const SizedBox(), // Hidden until flipped
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _showDeleteConfirm() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Word?"),
        content: const Text("You will not see this card again."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onDelete(); // Trigger delete callback
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildAltTranslationRow(String source, String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 6.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: isDark ? Colors.white12 : Colors.grey[200],
              borderRadius: BorderRadius.circular(4)
            ),
            child: Text(source, style: TextStyle(fontSize: 9, color: Colors.grey[600]))
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: isDark ? Colors.white70 : Colors.black87
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingBtn(String label, Color color, int rating) {
    final timeStr = SRSAlgorithm.getNextIntervalText(widget.item.status, rating);
    return InkWell(
      onTap: () => widget.onRated(rating),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 75,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(timeStr, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(int status) {
    if (status == 0) return Colors.blue;
    if (status < 5) return Colors.orange;
    return Colors.green;
  }

  String _getStatusLabel(int status) {
    if (status == 0) return 'New';
    if (status == 5) return 'Known';
    return 'Level $status';
  }
}

// ==========================================
// 📚 LIBRARY VIEW
// ==========================================
class LibraryView extends StatelessWidget {
  final List<VocabularyItem> items;
  const LibraryView({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (items.isEmpty) {
      return const Center(child: Text("No words in library yet."));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          elevation: 0,
          color: isDark ? Colors.white10 : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.withOpacity(0.2)),
          ),
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: CircleAvatar(
              backgroundColor: _getStatusColor(item.status).withOpacity(0.2),
              child: Text(
                '${item.status}',
                style: TextStyle(
                    color: _getStatusColor(item.status),
                    fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(item.word,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(item.translation),
            trailing: Text(
              _daysAgo(item.lastReviewed),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        );
      },
    );
  }

  String _daysAgo(DateTime date) {
    final diff = DateTime.now().difference(date).inDays;
    if (diff == 0) return "Today";
    return "$diff days ago";
  }

  Color _getStatusColor(int status) {
    if (status == 0) return Colors.blue;
    if (status < 5) return Colors.orange;
    return Colors.green;
  }
}