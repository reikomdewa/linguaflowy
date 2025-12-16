import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:linguaflow/models/vocabulary_item.dart';
// Import the player widget
import '../widgets/video_srs_player.dart';

class LibraryView extends StatefulWidget {
  final List<VocabularyItem> items;
  const LibraryView({super.key, required this.items});

  @override
  State<LibraryView> createState() => _LibraryViewState();
}

class _LibraryViewState extends State<LibraryView> {
  // State for filtering
  String _searchQuery = "";
  int _selectedFilter =
      -1; // -1 = All, 0 = New, 1 = Learning (<5), 2 = Known (5)
  final FlutterTts _flutterTts = FlutterTts();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 1. Filter Logic
    final filteredItems = widget.items.where((item) {
      // Search Filter
      final matchesSearch =
          item.word.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.translation.toLowerCase().contains(_searchQuery.toLowerCase());

      // Status Filter
      bool matchesStatus = true;
      if (_selectedFilter == 0) {
        matchesStatus = item.status == 0; // New
      } else if (_selectedFilter == 1)
        matchesStatus = item.status > 0 && item.status < 5; // Learning
      else if (_selectedFilter == 2)
        matchesStatus = item.status == 5; // Known

      return matchesSearch && matchesStatus;
    }).toList();

    // Sort: Newest first
    filteredItems.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Column(
      children: [
        // --- HEADER: Search & Chips ---
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          color: isDark ? Colors.black12 : Colors.white,
          child: Column(
            children: [
              // Search Bar
              TextField(
                decoration: InputDecoration(
                  hintText: "Search your words...",
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
              const SizedBox(height: 12),
              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip("All", -1),
                    const SizedBox(width: 8),
                    _buildFilterChip("New (Blue)", 0),
                    const SizedBox(width: 8),
                    _buildFilterChip("Learning", 1),
                    const SizedBox(width: 8),
                    _buildFilterChip("Mastered", 2),
                  ],
                ),
              ),
            ],
          ),
        ),

        // --- THE LIST ---
        Expanded(
          child: filteredItems.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredItems.length,
                  itemBuilder: (context, index) {
                    final item = filteredItems[index];
                    return _buildWordCard(item, isDark);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildWordCard(VocabularyItem item, bool isDark) {
    final hasContext =
        item.sentenceContext != null && item.sentenceContext!.isNotEmpty;
    final color = _getStatusColor(item.status);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withOpacity(0.1)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.5), width: 1.5),
          ),
          alignment: Alignment.center,
          child: Text(
            "${item.status}",
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        ),
        title: Text(
          item.word,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(
          item.translation,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.grey[600]),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // TTS Button
            IconButton(
              icon: Icon(
                Icons.volume_up_rounded,
                color: Colors.grey[400],
                size: 20,
              ),
              onPressed: () {
                _flutterTts.setLanguage(item.language);
                _flutterTts.speak(item.word);
              },
            ),
            if (hasContext) Icon(Icons.expand_more, color: Colors.grey[300]),
          ],
        ),

        // --- EXPANDED CONTENT ---
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                if (hasContext) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.format_quote_rounded,
                        size: 16,
                        color: Colors.blue[300],
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "Context:",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.sentenceContext!,
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: isDark ? Colors.grey[300] : Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Metadata row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Seen ${item.timesEncountered} times",
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),

                    // --- VIDEO BUTTON (Restored Look, Clickable) ---
                    if (item.sourceVideoUrl != null)
                      GestureDetector(
                        onTap: () => _showVideoContext(item),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.play_circle_outline,
                              size: 14,
                              color: Colors.grey,
                            ),
                            SizedBox(width: 4),
                            Text(
                              "Play Context",
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showVideoContext(VocabularyItem item) async {
    final videoUrl = item.sourceVideoUrl;

    if (videoUrl == null || videoUrl.isEmpty) return;

    // 1. CHECK IF FILE EXISTS LOCALLY
    // If it is NOT a network URL (YouTube/HTTP), we check the file system.
    bool isNetwork =
        videoUrl.toLowerCase().contains('http') ||
        videoUrl.toLowerCase().contains('youtube');

    if (!isNetwork) {
      final file = File(videoUrl);
      if (!file.existsSync()) {
        // File is missing: Show SnackBar and STOP.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "You deleted the local file so cannot show the context where you saw this",
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return; // <--- Do not open the dialog
      }
    }

    // 2. File exists (or is YouTube), proceed to show Dialog
    await showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 40), // Balance
                    const Text(
                      "Word Context",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Video Player
              SizedBox(
                height: 250,
                width: double.infinity,
                child: VideoSRSPlayer(
                  videoUrl: videoUrl,
                  startSeconds: item.timestamp ?? 0.0,
                  endSeconds: (item.timestamp ?? 0.0) + 10.0,
                  isStandalone: true,
                ),
              ),

              // Subtitle Text Below Video
              if (item.sentenceContext != null)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    item.sentenceContext!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );

    // 3. FORCE PORTRAIT ON CLOSE
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  Widget _buildFilterChip(String label, int value) {
    final isSelected = _selectedFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (bool selected) {
        setState(() => _selectedFilter = selected ? value : -1);
      },
      selectedColor: Colors.blueAccent,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? Colors.transparent : Colors.grey[300]!,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text("No words found", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Color _getStatusColor(int status) {
    if (status == 0) return Colors.blue;
    if (status < 3) return Colors.redAccent;
    if (status < 5) return Colors.orange;
    return Colors.green;
  }
}
