import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:linguaflow/models/vocabulary_item.dart';
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
  State<Flashcard> createState() => _FlashcardState();
}

class _FlashcardState extends State<Flashcard>
    with SingleTickerProviderStateMixin {
  bool _isRevealed = false;
  late AnimationController _controller;
  late Animation<double> _animation;

  // --- SMART MEDIA STATE ---
  bool _hasVideo = false;
  bool _showVideoOnFront = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(_controller);

    // --- VIDEO AVAILABILITY CHECK ---
    final videoUrl = widget.item.sourceVideoUrl;
    if (videoUrl != null && videoUrl.isNotEmpty) {
      if (videoUrl.toLowerCase().contains('http') ||
          videoUrl.toLowerCase().contains('youtube')) {
        _hasVideo = true;
      } else {
        _hasVideo = File(videoUrl).existsSync();
      }
    }

    // --- SMART CONTEXT LOGIC ---
    if (_hasVideo) {
      // New words always show video for context. 
      // Mastered words show it 70% of the time to keep recall challenging.
      _showVideoOnFront = (widget.item.status <= 1) || (Random().nextDouble() <= 0.7);
    }
  }

  void _flip() {
    if (_isRevealed) return;
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
    final cardBg = isDark ? const Color(0xFF2C2C2C) : Colors.white;
    final txtColor = isDark ? Colors.white : Colors.black87;

    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _flip,
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // CARD CONTENT
                  SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildStatusBadge(),
                        const SizedBox(height: 12),
                        
                        if (!_isRevealed)
                          Text("(Tap to reveal)", style: TextStyle(color: Colors.grey[400], fontSize: 11)),

                        const SizedBox(height: 20),

                        // --- FRONT VIDEO ---
                        if (_hasVideo && _showVideoOnFront) _buildVideoPlayer(),

                        // --- THE WORD ---
                        Text(
                          widget.item.word,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: (_hasVideo && _showVideoOnFront) ? 28 : 34,
                            fontWeight: FontWeight.bold,
                            color: txtColor,
                          ),
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
                                color: isDark ? Colors.grey[400] : Colors.grey[700],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),

                        // --- BACK (REVEALED) ---
                        FadeTransition(
                          opacity: _animation,
                          child: Column(
                            children: [
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: Divider(color: Colors.white10),
                              ),

                              // BACK VIDEO (If hidden on front)
                              if (_isRevealed && _hasVideo && !_showVideoOnFront)
                                _buildVideoPlayer(),

                              Text(
                                widget.item.translation,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 26,
                                  color: Colors.blueAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              
                              if (widget.item.notes != null && widget.item.notes!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 10.0),
                                  child: Text(
                                    widget.item.notes!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // TOP RIGHT ACTIONS
                  Positioned(
                    top: 10,
                    right: 15,
                    child: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 20),
                      onPressed: _showDeleteConfirm,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        
        // RATING BUTTONS
        const SizedBox(height: 16),
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
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildVideoPlayer() {
    return Container(
      height: 180,
      margin: const EdgeInsets.only(bottom: 20),
      child: VideoSRSPlayer(
        videoUrl: widget.item.sourceVideoUrl!,
        startSeconds: widget.item.timestamp ?? 0.0,
        endSeconds: (widget.item.timestamp ?? 0.0) + 5.0,
      ),
    );
  }

  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor(widget.item.status).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _getStatusColor(widget.item.status).withOpacity(0.3))
      ),
      child: Text(
        _getStatusLabel(widget.item.status).toUpperCase(),
        style: TextStyle(
          color: _getStatusColor(widget.item.status),
          fontWeight: FontWeight.bold,
          fontSize: 9,
          letterSpacing: 1.1
        ),
      ),
    );
  }

  Widget _buildRatingBtn(String label, Color color, int rating) {
    final timeStr = SRSAlgorithm.getNextIntervalText(widget.item.status, rating);
    return InkWell(
      onTap: () => widget.onRated(rating),
      borderRadius: BorderRadius.circular(15),
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
            const SizedBox(height: 4),
            Text(timeStr, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirm() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Flashcard?"),
        content: const Text("This word will be removed from your library permanently."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onDelete();
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(int status) {
    if (status == 0) return Colors.blueAccent;
    if (status < 5) return Colors.orange;
    return Colors.green;
  }

  String _getStatusLabel(int status) {
    if (status == 0) return 'New';
    if (status == 5) return 'Mastered';
    return 'Level $status';
  }
}