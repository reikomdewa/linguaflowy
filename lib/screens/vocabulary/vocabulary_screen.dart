import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/vocabulary/vocabulary_bloc.dart';
import 'package:linguaflow/models/vocabulary_item.dart';
import 'dart:math' as math;

// ==========================================
// 🧠 SMART SRS ALGORITHM (The Brain)
// ==========================================
class SRSAlgorithm {
  // Returns true if the word should be reviewed today
  static bool isDue(VocabularyItem item) {
    if (item.status == 0) return true; // New words always due

    final now = DateTime.now();
    final difference = now.difference(item.lastReviewed).inDays;

    // Mapping Status (0-5) to Days required before next review
    // 1: 1 day, 2: 3 days, 3: 7 days, 4: 14 days, 5: 30+ days
    int requiredGap;
    switch (item.status) {
      case 1: requiredGap = 0; break; // Let them review Status 1 same day if they want
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

class _VocabularyScreenState extends State<VocabularyScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
    context.read<VocabularyBloc>().add(VocabularyLoadRequested(user.id));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Color(0xFF121212) : Colors.grey[100];

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text('Smart Flashcards', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: isDark ? Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blueAccent,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blueAccent,
          tabs: [
            Tab(text: "Review Deck"),
            Tab(text: "All Words"),
          ],
        ),
      ),
      body: BlocBuilder<VocabularyBloc, VocabularyState>(
        builder: (context, state) {
          if (state is VocabularyLoading) return Center(child: CircularProgressIndicator());
          
          if (state is VocabularyLoaded) {
            // 1. Separate items
            final dueItems = state.items.where((i) => SRSAlgorithm.isDue(i)).toList();
            // Sort due items: Newest first, then oldest reviewed
            dueItems.sort((a, b) => a.status.compareTo(b.status));

            return TabBarView(
              controller: _tabController,
              physics: NeverScrollableScrollPhysics(), // Important for swipe cards
              children: [
                ReviewSessionView(
                  dueItems: dueItems, 
                  allItems: state.items, // Pass all for Cram mode
                ),
                LibraryView(items: state.items),
              ],
            );
          }
          return Center(child: Text("Error loading vocabulary"));
        },
      ),
    );
  }
}

// ==========================================
// 🃏 REVIEW SESSION VIEW (The Anki Logic)
// ==========================================
class ReviewSessionView extends StatefulWidget {
  final List<VocabularyItem> dueItems;
  final List<VocabularyItem> allItems;

  const ReviewSessionView({super.key, required this.dueItems, required this.allItems});

  @override
  _ReviewSessionViewState createState() => _ReviewSessionViewState();
}

class _ReviewSessionViewState extends State<ReviewSessionView> {
  // We use a local queue so the UI doesn't jump when the Bloc updates the master list
  List<VocabularyItem> _sessionQueue = [];
  bool _isSessionActive = false;
  bool _isCramMode = false;

  @override
  void initState() {
    super.initState();
    // Auto-start if items are due
    if (widget.dueItems.isNotEmpty) {
      _startSession(widget.dueItems);
    }
  }

  void _startSession(List<VocabularyItem> items, {bool cram = false}) {
    setState(() {
      // Take top 20 to prevent fatigue, or all if less
      _sessionQueue = List.from(items.take(20));
      _isSessionActive = true;
      _isCramMode = cram;
    });
  }

  void _handleRating(int rating) {
    if (_sessionQueue.isEmpty) return;

    final currentItem = _sessionQueue[0];
    
    // 1. Calculate New Data
    final newStatus = SRSAlgorithm.nextStatus(currentItem.status, rating);
    final newItem = currentItem.copyWith(
      status: newStatus,
      lastReviewed: DateTime.now(), // Updates "Today"
      timesEncountered: currentItem.timesEncountered + 1,
    );

    // 2. Update Firebase via Bloc
    context.read<VocabularyBloc>().add(VocabularyUpdateRequested(newItem));

    // 3. Update Local Queue (Remove current card)
    setState(() {
      _sessionQueue.removeAt(0);
      if (_sessionQueue.isEmpty) {
        _isSessionActive = false; // Session Complete
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // --- STATE: SESSION ACTIVE ---
    if (_isSessionActive && _sessionQueue.isNotEmpty) {
      final item = _sessionQueue.first;
      return Column(
        children: [
          _buildProgressBar(isDark),
          Expanded(
            child: Flashcard(
              key: ValueKey(item.id), // Key forces rebuild/animation on new item
              item: item,
              onRated: _handleRating,
            ),
          ),
        ],
      );
    }

    // --- STATE: NOTHING DUE (Empty State) ---
    // If we are here, either queue is empty or nothing was due initially
    final dueCount = widget.dueItems.length; // Live count from Bloc
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_rounded, size: 80, color: Colors.green[300]),
            SizedBox(height: 24),
            Text(
              dueCount > 0 ? "Ready to Review?" : "All Caught Up!",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text(
              dueCount > 0 
                ? "You have $dueCount words waiting for you."
                : "No cards are strictly due right now.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            SizedBox(height: 40),
            
            // Start Due Session
            if (dueCount > 0)
              _buildLargeButton(
                icon: Icons.play_arrow_rounded,
                label: "Start Daily Review ($dueCount)",
                color: Colors.blue,
                onTap: () => _startSession(widget.dueItems),
              ),

            SizedBox(height: 16),

            // Start Cram Session (Even if not due)
            if (dueCount == 0) ...[
              Text("Want to study anyway?", style: TextStyle(color: Colors.grey)),
              SizedBox(height: 16),
              _buildLargeButton(
                icon: Icons.bolt_rounded,
                label: "Cram Session (Random 20)",
                color: Colors.orange,
                onTap: () {
                  // Shuffle and take 20
                  final mixed = List<VocabularyItem>.from(widget.allItems)..shuffle();
                  _startSession(mixed, cram: true);
                },
              ),
              SizedBox(height: 12),
              _buildLargeButton(
                icon: Icons.refresh_rounded,
                label: "Revise Known Words",
                color: Colors.green,
                onTap: () {
                  final known = widget.allItems.where((i) => i.status == 5).toList()..shuffle();
                  _startSession(known, cram: true);
                },
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(bool isDark) {
    final total = 20; // Assuming batch of 20
    final current = total - _sessionQueue.length;
    final pct = current / total;

    return Container(
      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_isCramMode ? "🔥 Cramming" : "📚 Daily Review", style: TextStyle(fontWeight: FontWeight.bold)),
              Text("${_sessionQueue.length} left", style: TextStyle(color: Colors.grey)),
            ],
          ),
          SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct > 1.0 ? 1.0 : pct,
              minHeight: 6,
              backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLargeButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: Icon(icon, color: Colors.white),
        label: Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 4,
        ),
      ),
    );
  }
}

// ==========================================
// 💳 FLASHCARD WIDGET
// ==========================================
class Flashcard extends StatefulWidget {
  final VocabularyItem item;
  final Function(int) onRated;

  const Flashcard({super.key, required this.item, required this.onRated});

  @override
  _FlashcardState createState() => _FlashcardState();
}

class _FlashcardState extends State<Flashcard> with SingleTickerProviderStateMixin {
  bool _isRevealed = false;
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: Duration(milliseconds: 300));
    _animation = Tween<double>(begin: 0, end: 1).animate(_controller);
  }

  void _flip() {
    setState(() => _isRevealed = true);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? Color(0xFF2C2C2C) : Colors.white;
    final txtColor = isDark ? Colors.white : Colors.black87;

    return Column(
      children: [
        // --- CARD AREA ---
        Expanded(
          child: GestureDetector(
            onTap: _isRevealed ? null : _flip,
            child: Container(
              width: double.infinity,
              margin: EdgeInsets.symmetric(horizontal: 20),
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 15,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Status Badge
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(widget.item.status).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _getStatusLabel(widget.item.status).toUpperCase(),
                      style: TextStyle(color: _getStatusColor(widget.item.status), fontWeight: FontWeight.bold, fontSize: 10),
                    ),
                  ),
                  Spacer(),
                  
                  // FRONT (Word)
                  Text(
                    widget.item.word,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: txtColor),
                  ),
                  
                  SizedBox(height: 20),
                  
                  // BACK (Translation - Revealed with animation)
                  FadeTransition(
                    opacity: _animation,
                    child: Column(
                      children: [
                        Divider(color: Colors.grey.withOpacity(0.3)),
                        SizedBox(height: 10),
                        Text(
                          widget.item.translation,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 24, color: Colors.blueAccent, fontWeight: FontWeight.w500),
                        ),
                        if (widget.item.notes != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 10.0),
                            child: Text(
                              widget.item.notes!,
                              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Spacer(),
                  if (!_isRevealed)
                    Text("Tap to flip", style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                ],
              ),
            ),
          ),
        ),

        // --- BUTTONS AREA ---
        SizedBox(height: 20),
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
              : SizedBox(), // Empty when not revealed
        ),
        SizedBox(height: 20),
      ],
    );
  }

  Widget _buildRatingBtn(String label, Color color, int rating) {
    // Get time estimate string
    final timeStr = SRSAlgorithm.getNextIntervalText(widget.item.status, rating);

    return InkWell(
      onTap: () => widget.onRated(rating),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 75,
        padding: EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
            SizedBox(height: 4),
            Text(timeStr, style: TextStyle(fontSize: 10, color: Colors.grey)),
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
// 📚 LIBRARY VIEW (List)
// ==========================================
class LibraryView extends StatelessWidget {
  final List<VocabularyItem> items;

  const LibraryView({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (items.isEmpty) {
      return Center(child: Text("No words in library yet."));
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
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
          margin: EdgeInsets.only(bottom: 8),
          child: ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: CircleAvatar(
              backgroundColor: _getStatusColor(item.status).withOpacity(0.2),
              child: Text(
                '${item.status}',
                style: TextStyle(color: _getStatusColor(item.status), fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(item.word, style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(item.translation),
            trailing: Text(
              _daysAgo(item.lastReviewed),
              style: TextStyle(fontSize: 12, color: Colors.grey),
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