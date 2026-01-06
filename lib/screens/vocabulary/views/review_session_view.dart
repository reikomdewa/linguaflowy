// ==========================================
// 🃏 REVIEW SESSION VIEW (DATA-VALIDATED)
// ==========================================
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_event.dart';
import 'package:linguaflow/blocs/auth/auth_state.dart';
import 'package:linguaflow/blocs/vocabulary/vocabulary_bloc.dart';
import 'package:linguaflow/models/vocabulary_item.dart';
import 'package:linguaflow/screens/vocabulary/widgets/flashcard_widget.dart';
import 'package:linguaflow/utils/language_helper.dart';
import 'package:linguaflow/utils/srs_algorithm.dart';
import 'package:linguaflow/utils/utils.dart';

class ReviewSessionView extends StatefulWidget {
  final List<VocabularyItem> dueItems;
  final List<VocabularyItem> allItems;

  const ReviewSessionView({
    super.key,
    required this.dueItems,
    required this.allItems,
  });

  @override
  State<ReviewSessionView> createState() => _ReviewSessionViewState();
}

class _ReviewSessionViewState extends State<ReviewSessionView> {
  List<VocabularyItem> _sessionQueue = [];
  List<VocabularyItem> _lastSessionItems = []; // Tracks the last batch played
  bool _isSessionActive = false;
  bool _isCramMode = false;

  int _sessionXpAccumulator = 0;
  DateTime _cardStartTime = DateTime.now();
  int _cardsSinceLastVerification = 0;
  int _totalCardsProcessed = 0;

  bool _isVerifying = false;
  List<String> _currentOptions = [];

  @override
  void initState() {
    super.initState();
    if (widget.dueItems.isNotEmpty) {
      _startSession(widget.dueItems);
    }
  }

  void _startSession(List<VocabularyItem> items, {bool cram = false}) {
    // FIX: Filter out any items that have empty translations
    final validItems = items
        .where((i) => i.translation.trim().isNotEmpty)
        .toList();

    setState(() {
      // Store this specific batch so we can "Redo same list"
      _lastSessionItems = List.from(validItems.take(20));
      _sessionQueue = List.from(_lastSessionItems);

      _isSessionActive = true;
      _isCramMode = cram;
      _sessionXpAccumulator = 0;
      _totalCardsProcessed = 0;
      _cardsSinceLastVerification = 0;

      if (_sessionQueue.isNotEmpty) {
        _isVerifying = true;
        _currentOptions = _generateOptions(_sessionQueue.first);
      }
      _cardStartTime = DateTime.now();
    });
  }

  List<String> _generateOptions(VocabularyItem correctItem) {
    final Set<String> options = {};
    String correct = correctItem.translation.trim();
    options.add(correct);

    List<String> others = widget.allItems
        .where(
          (item) =>
              item.language == correctItem.language &&
              item.translation.trim().toLowerCase() != correct.toLowerCase() &&
              item.translation.trim().isNotEmpty,
        )
        .map((item) => item.translation.trim())
        .toList();

    others.shuffle();
    for (var distractor in others) {
      if (options.length >= 4) break;
      options.add(distractor);
    }

    final List<String> fallbackFillers = [
      "Not the answer",
      "Incorrect",
      "Wrong choice",
      "Try again",
      "Something else",
    ];
    fallbackFillers.shuffle();
    while (options.length < 4) {
      options.add(fallbackFillers.removeAt(0));
    }

    final List<String> finalOptions = options.toList();
    finalOptions.shuffle();
    return finalOptions;
  }

  void _handleRating(int rating, {bool wasRevealed = true}) {
    if (_sessionQueue.isEmpty) return;
    final currentItem = _sessionQueue[0];
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    final oldStatus = currentItem.status;
    final newStatus = SRSAlgorithm.nextStatus(oldStatus, rating);

    int xpGained = 0;
    if (!wasRevealed && rating > 1) {
      xpGained = 0;
    } else if (rating == 1) {
      xpGained = 2;
    } else {
      xpGained = LanguageHelper.calculateSmartXP(
        word: currentItem.word,
        langCode: currentItem.language,
        oldStatus: oldStatus,
        newStatus: newStatus,
        userLevel: authState.user.currentLevel,
      );
      if (rating == 3) xpGained += 2;
      if (rating == 4) xpGained += 3;
    }

    final sessionDuration = DateTime.now().difference(_cardStartTime);
    if (sessionDuration.inMilliseconds < 1500 && rating > 1) {
      xpGained = 0;
    }

    _sessionXpAccumulator += xpGained;
    context.read<AuthBloc>().add(AuthUpdateXP(xpGained));

    final newItem = currentItem.copyWith(
      status: newStatus,
      lastReviewed: DateTime.now(),
      timesEncountered: currentItem.timesEncountered + 1,
    );

    context.read<VocabularyBloc>().add(VocabularyUpdateRequested(newItem));
    _advanceQueue();
  }

  void _advanceQueue() {
    setState(() {
      _sessionQueue.removeAt(0);
      _totalCardsProcessed++;
      _cardStartTime = DateTime.now();

      if (_sessionQueue.isNotEmpty) {
        bool forceQuiz =
            (_totalCardsProcessed < 3) || (_cardsSinceLastVerification >= 2);
        _isVerifying = forceQuiz || (Random().nextDouble() < 0.4);

        if (_isVerifying) {
          _currentOptions = _generateOptions(_sessionQueue.first);
          _cardsSinceLastVerification = 0;
        } else {
          _cardsSinceLastVerification++;
        }
      } else {
        _isSessionActive = false;
        _showFinalSessionResults();
      }
    });
  }

  void _showFinalSessionResults() {
    const int completionBonus = 20;
    final int finalTotal = _sessionXpAccumulator + completionBonus;
    context.read<AuthBloc>().add(AuthUpdateXP(completionBonus));
    Utils.showXpPop(finalTotal, context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.blueAccent,
        content: Text("🏆 Session Complete! Earned: $finalTotal XP"),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleDelete() {
    if (_sessionQueue.isEmpty) return;
    context.read<VocabularyBloc>().add(
      VocabularyDeleteRequested(
        id: _sessionQueue[0].id,
        userId: _sessionQueue[0].userId,
      ),
    );
    _advanceQueue();
  }

  void _handleKeepGoing() {
    final validDueItems = widget.dueItems
        .where((i) => i.translation.trim().isNotEmpty)
        .toList();

    if (validDueItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.white,
          content: Text("📚 No more cards to review! Try Random Cram instead."),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
    } else {
      _startSession(widget.dueItems);
    }
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
            child: _isVerifying
                ? _buildVerificationUI(item, isDark)
                : Flashcard(
                    key: ValueKey("rv_${item.id}"),
                    item: item,
                    onRated: (rating) =>
                        _handleRating(rating, wasRevealed: true),
                    onDelete: _handleDelete,
                  ),
          ),
        ],
      );
    }

    return _buildEmptyState(isDark);
  }

  Widget _buildVerificationUI(VocabularyItem item, bool isDark) {
    // Charcoal theme colors
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.amber.withOpacity(0.4) : Colors.amber.withOpacity(0.6);
    final textColor = isDark ? Colors.white : Colors.black87;
    
    // Button styling for multiple choice
    final buttonBg = isDark ? Colors.white10 : Colors.grey[100];
    final buttonBorder = isDark ? Colors.white24 : Colors.black12;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_user, color: isDark ? Colors.amber : Colors.amber[700], size: 40),
            const SizedBox(height: 10),
            Text(
              "Earn an XP Bonus!",
              style: TextStyle(
                color: isDark ? Colors.amber : Colors.amber[800],
                fontWeight: FontWeight.bold,
                fontSize: 11,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              item.word,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 34, 
                fontWeight: FontWeight.bold,
                color: textColor
              ),
            ),
            if (item.sentenceContext != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  item.sentenceContext!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                    fontSize: 15,
                  ),
                ),
              ),
            const SizedBox(height: 30),
            ..._currentOptions.map(
              (opt) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      backgroundColor: buttonBg,
                      foregroundColor: textColor,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                        side: BorderSide(color: buttonBorder),
                      ),
                    ),
                    onPressed: () {
                      if (opt.trim().toLowerCase() ==
                          item.translation.trim().toLowerCase()) {
                        setState(() => _isVerifying = false);
                      } else {
                        _handleRating(1);
                      }
                    },
                    child: Text(
                      opt,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(bool isDark) {
    const total = 20;
    final current = total - _sessionQueue.length;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isVerifying ? "🛡️ Verifying..." : "📚 Reviewing",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _isVerifying ? Colors.amber : Colors.blue,
                ),
              ),
              Text(
                "${_sessionQueue.length} left",
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: (current / total).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: isDark ? Colors.white10 : Colors.black12,
              valueColor: AlwaysStoppedAnimation<Color>(
                _isVerifying ? Colors.amber : Colors.blueAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    final dueCount = widget.dueItems.length;
    final hasLastSession = _lastSessionItems.isNotEmpty;
    const int completionBonus = 20;
    final int finalTotal = _sessionXpAccumulator + completionBonus;
    
    // Note: XP update removed from here to prevent build loop. 
    // It is handled in _showFinalSessionResults.

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  dueCount == 0
                      ? Icons.check_circle_rounded
                      : Icons.emoji_events_rounded,
                  size: 80,
                  color: dueCount == 0 ? Colors.green : Colors.amber[400],
                ),
                const SizedBox(width: 16),
                Text(
                  "+$finalTotal XP",
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              dueCount == 0 ? "You finished all cards!" : "Great Job!",
              style: TextStyle(
                fontSize: 26, 
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87
              ),
            ),
            const SizedBox(height: 12),
            Text(
              dueCount > 0
                  ? "You still have cards to review."
                  : "You've caught up with your schedule. Try a cram session?",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 40),

            // If we have items left in the "Due" list, show Keep Going
            if (dueCount > 0)
              _buildLargeButton(
                icon: Icons.play_arrow,
                label: "Keep Going",
                isPrimary: true,
                isDark: isDark,
                onTap: _handleKeepGoing,
              ),

            // If we are truly finished, show "Same Cards" to redo the last batch
            if (dueCount == 0 && hasLastSession)
              _buildLargeButton(
                icon: Icons.replay,
                label: "Same Cards",
                isPrimary: false,
                isDark: isDark,
                onTap: () => _startSession(_lastSessionItems, cram: true),
              ),

            const SizedBox(height: 12),

            // Random Cram 
            _buildLargeButton(
              icon: Icons.shuffle,
              label: "Random Cram",
              isPrimary: false,
              isDark: isDark,
              onTap: () {
                final mixed = List<VocabularyItem>.from(widget.allItems)
                  ..shuffle();
                _startSession(mixed, cram: true);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLargeButton({
    required IconData icon,
    required String label,
    required bool isPrimary,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    // Determine colors based on Theme and Importance (Primary/Secondary)
    
    Color bgColor;
    Color textColor;
    BorderSide borderSide;

    if (isDark) {
      // CHARCOAL / DARK MODE
      if (isPrimary) {
        // Subtle white glassy look for primary
        bgColor = Colors.white.withOpacity(0.12);
        textColor = Colors.white;
        borderSide = BorderSide(color: Colors.white.withOpacity(0.2));
      } else {
        // Transparent/Outline for secondary
        bgColor = Colors.transparent;
        textColor = Colors.white70;
        borderSide = BorderSide(color: Colors.white.withOpacity(0.1));
      }
    } else {
      // LIGHT MODE
      if (isPrimary) {
        // Solid Dark Charcoal for primary action in light mode (High Contrast)
        bgColor = const Color(0xFF2C2C2C);
        textColor = Colors.white;
        borderSide = BorderSide.none;
      } else {
        // Light Grey for secondary
        bgColor = const Color(0xFFF0F0F0);
        textColor = Colors.black87;
        borderSide = const BorderSide(color: Color(0xFFE0E0E0));
      }
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: Icon(icon, color: textColor),
        label: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold, 
            fontSize: 16,
            color: textColor
          ),
        ),
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: textColor,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: borderSide,
          ),
          elevation: isPrimary ? 2 : 0,
          shadowColor: Colors.black12,
        ),
      ),
    );
  }
}