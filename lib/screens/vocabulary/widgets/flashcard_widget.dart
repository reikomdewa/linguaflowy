import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/models/vocabulary_item.dart';
import 'package:linguaflow/services/mymemory_service.dart';
import 'package:linguaflow/services/translation_service.dart';
import 'package:linguaflow/utils/srs_algorithm.dart';
import 'video_srs_player.dart'; 

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

class _FlashcardState extends State<Flashcard> with SingleTickerProviderStateMixin {
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

    try {
      mmResult = await MyMemoryService.translate(
        text: widget.item.word,
        sourceLang: widget.item.language,
        targetLang: user.nativeLanguage,
      );
    } catch (_) {}

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

    final bool hasVideo = widget.item.sourceVideoUrl != null && 
                          widget.item.sourceVideoUrl!.isNotEmpty;

    return Dismissible(
      key: ValueKey(widget.item.id),
      direction: DismissDirection.horizontal,
      background: _buildSwipeBg(Colors.green, Icons.thumb_up_alt_rounded, "Good", Alignment.centerLeft),
      secondaryBackground: _buildSwipeBg(Colors.orange, Icons.refresh_rounded, "Again", Alignment.centerRight),
      onDismissed: (direction) {
        if (direction == DismissDirection.startToEnd) {
          widget.onRated(3);
        } else {
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
                    // Removed padding here to let ScrollView handle it
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
                    // 1. Center acts as a parent for short content
                    child: Center(
                      // 2. SingleChildScrollView allows long content (video + text) to scroll
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min, // Shrink wrap content
                          children: [
                            // --- STATUS BADGE ---
                            _buildStatusBadge(),
                            
                            const SizedBox(height: 16),

                            // --- VIDEO PLAYER ---
                            if (hasVideo)
                              Container(
                                height: 200, // Fixed height for video container
                                margin: const EdgeInsets.only(bottom: 20),
                                child: VideoSRSPlayer(
                                  videoUrl: widget.item.sourceVideoUrl!,
                                  startSeconds: widget.item.timestamp ?? 0.0,
                                  endSeconds: (widget.item.timestamp ?? 0.0) + 5.0, 
                                ),
                              ),

                            // --- FRONT (Word) ---
                            Text(
                              widget.item.word,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: hasVideo ? 26 : 32, 
                                  fontWeight: FontWeight.bold,
                                  color: txtColor),
                            ),

                            // --- SENTENCE CONTEXT ---
                            if (widget.item.sentenceContext != null)
                               Padding(
                                 padding: const EdgeInsets.only(top: 12.0),
                                 child: Text(
                                   widget.item.sentenceContext!,
                                   textAlign: TextAlign.center,
                                   style: TextStyle(
                                     fontSize: 16,
                                     color: isDark ? Colors.grey[300] : Colors.grey[800],
                                     fontStyle: FontStyle.italic
                                   ),
                                 ),
                               ),

                            const SizedBox(height: 20),

                            // --- BACK (Revealed Content) ---
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

                                  if (widget.item.notes != null && widget.item.notes!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 10.0),
                                      child: Text(
                                        widget.item.notes!,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            color: Colors.grey, fontStyle: FontStyle.italic),
                                      ),
                                    ),

                                  if (_isRevealed) ...[
                                    const SizedBox(height: 20),
                                    if (_isLoadingExtra)
                                      const SizedBox(height: 15, width: 15, child: CircularProgressIndicator(strokeWidth: 2))
                                    else
                                      Column(
                                        children: [
                                          if (_myMemoryTranslation != null && _myMemoryTranslation!.isNotEmpty)
                                            _buildAltTranslationRow("MyMemory", _myMemoryTranslation!, isDark),
                                          if (_googleTranslation != null && _googleTranslation!.isNotEmpty)
                                            _buildAltTranslationRow("Google", _googleTranslation!, isDark),
                                        ],
                                      ),
                                  ]
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 20),
                            
                            if (!_isRevealed)
                              Text("Tap to flip", style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Menu Button (Absolute position, sits on top of scroll view)
                  Positioned(
                    top: 10,
                    right: 30,
                    child: PopupMenuButton<String>(
                      icon: Icon(Icons.more_horiz, color: Colors.grey[400]),
                      onSelected: (value) { if (value == 'delete') _showDeleteConfirm(); },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(children: [Icon(Icons.delete_outline, color: Colors.red), SizedBox(width: 8), Text("Delete Card", style: TextStyle(color: Colors.red))]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- RATING BUTTONS ---
          // Outside the scroll view so they are always accessible
          const SizedBox(height: 20),
          SizedBox(
            height: 100,
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
                : const SizedBox(),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Container _buildSwipeBg(Color color, IconData icon, String label, Alignment alignment) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      alignment: alignment,
      padding: EdgeInsets.only(left: alignment == Alignment.centerLeft ? 30 : 0, right: alignment == Alignment.centerRight ? 30 : 0),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: Colors.white, size: 40), Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]),
    );
  }

  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor(widget.item.status).withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _getStatusLabel(widget.item.status).toUpperCase(),
        style: TextStyle(color: _getStatusColor(widget.item.status), fontWeight: FontWeight.bold, fontSize: 10),
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
  
  Widget _buildAltTranslationRow(String source, String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 6.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(color: isDark ? Colors.white12 : Colors.grey[200], borderRadius: BorderRadius.circular(4)),
            child: Text(source, style: TextStyle(fontSize: 9, color: Colors.grey[600]))
          ),
          const SizedBox(width: 6),
          Flexible(child: Text(text, style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: isDark ? Colors.white70 : Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis)),
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(onPressed: () { Navigator.pop(context); widget.onDelete(); }, child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
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