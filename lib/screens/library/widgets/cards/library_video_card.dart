import 'dart:io';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:linguaflow/screens/library/widgets/dialogs/library_actions.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/screens/reader/reader_screen.dart';

// We removed media_kit imports because we don't need to play video here anymore.

class LibraryVideoCard extends StatefulWidget {
  final LessonModel lesson;
  final bool isDark;
  final double? width;

  const LibraryVideoCard({
    super.key,
    required this.lesson,
    required this.isDark,
    this.width,
  });

  @override
  State<LibraryVideoCard> createState() => _LibraryVideoCardState();
}

class _LibraryVideoCardState extends State<LibraryVideoCard> {
  bool _isAudioOnly = false;

  @override
  void initState() {
    super.initState();
    _checkMediaType();
  }

  void _checkMediaType() {
    // 1. Explicitly marked as audio
    if (widget.lesson.type == 'audio') {
      setState(() => _isAudioOnly = true);
      return;
    }

    // 2. Fallback: Check extension
    final path = widget.lesson.videoUrl ?? "";
    final ext = path.toLowerCase();
    if (ext.endsWith('.mp3') ||
        ext.endsWith('.wav') ||
        ext.endsWith('.aac') ||
        ext.endsWith('.m4a')) {
      setState(() => _isAudioOnly = true);
    }
  }

  bool get _isYoutube {
    final path = widget.lesson.videoUrl ?? widget.lesson.content;
    if (path == null) return false;
    return path.toLowerCase().contains('youtube.com') ||
        path.toLowerCase().contains('youtu.be');
  }

  String? _getYoutubeId(String url) {
    final RegExp regExp = RegExp(
      r'^.*((youtu.be\/)|(v\/)|(\/u\/\w\/)|(embed\/)|(watch\?))\??v?=?([^#&?]*).*',
      caseSensitive: false,
      multiLine: false,
    );
    final match = regExp.firstMatch(url);
    if (match != null && match.groupCount >= 7) {
      return match.group(7);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReaderScreen(lesson: widget.lesson),
          ),
        );
      },
      child: Container(
        width: widget.width,
        decoration: BoxDecoration(
          color: widget.isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                // 1. Thumbnail Area
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: Container(
                    height: 140,
                    width: double.infinity,
                    color: widget.isDark ? Colors.black : Colors.grey[200],
                    child: _buildMediaContent(),
                  ),
                ),
              ],
            ),

            // 3. Details Section
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SizedBox(
                          height:
                              15 *
                              1.2 *
                              2, // fontSize * lineHeight * numberOfLines
                          child: Text(
                            widget.lesson.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: widget.isDark
                                  ? Colors.white
                                  : Colors.black,
                            ),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => showLessonOptions(
                          context,
                          widget.lesson,
                          widget.isDark,
                        ),
                        child: const Icon(
                          Icons.more_vert,
                          color: Colors.grey,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SizedBox(height: 18, child: _buildSourceIndicator()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _getYoutubeThumbnail(String videoUrl) {
    if (videoUrl.isEmpty) return null;
    // Regex to find the video ID from various YouTube URL formats
    RegExp regExp = RegExp(
      r'^.*((youtu.be\/)|(v\/)|(\/u\/\w\/)|(embed\/)|(watch\?))\??v?=?([^#&?]*).*',
      caseSensitive: false,
      multiLine: false,
    );
    final match = regExp.firstMatch(videoUrl);
    final String? id = (match != null && match.groupCount >= 7)
        ? match.group(7)
        : null;

    // Return high quality thumbnail if ID is found
    if (id != null && id.length == 11) {
      return 'https://img.youtube.com/vi/$id/hqdefault.jpg';
    }
    return null;
  }

  // --- WIDGET HELPERS ---
  Widget _buildMediaContent() {
    // 1. Audio Placeholder Logic
    if (_isAudioOnly) {
      // --- START NEW CHECK ---
      // Even if it's audio only, if we have a YouTube link, show the thumbnail
      final String? youtubeThumb = _getYoutubeThumbnail(
        widget.lesson.videoUrl!,
      );

      if (youtubeThumb != null) {
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              youtubeThumb,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                // If loading image fails, show the headphones icon
                return Center(
                  child: Icon(
                    Icons.headphones,
                    size: 50,
                    color: widget.isDark ? Colors.white70 : Colors.blue[300],
                  ),
                );
              },
            ),
            // Optional: Add a subtle overlay so white text/icons pop
            Container(color: Colors.black12),
          ],
        );
      }
      // --- END NEW CHECK ---

      // Default: No Video URL -> Show Headphones
      return Container(
        color: widget.isDark ? Colors.grey[800] : Colors.blue[50],
        child: Center(
          child: Icon(
            Icons.headphones,
            size: 50,
            color: widget.isDark ? Colors.white70 : Colors.blue[300],
          ),
        ),
      );
    }

    // 2. Display the Image (Generated Screenshot or Network URL)
    final String? imagePath = widget.lesson.imageUrl;

    if (imagePath != null && imagePath.isNotEmpty) {
      // Check if it is a Local File (created by your import function)
      final File localFile = File(imagePath);
      if (localFile.existsSync()) {
        return Image.file(
          localFile,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
        );
      }
      // Else assume it is a Network URL (legacy or web imports)
      else {
        return Image.network(
          imagePath,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
        );
      }
    }

    // 3. Fallback for YouTube or missing images
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    // Try to get YouTube thumbnail if no other image exists
    final String? videoPath = widget.lesson.videoUrl;
    if (videoPath != null &&
        (videoPath.contains('youtube.com') || videoPath.contains('youtu.be'))) {
      final String? videoId = _getYoutubeId(videoPath);
      if (videoId != null) {
        // FIX: Added correct YouTube thumbnail URL format
        return Image.network(
          'https://img.youtube.com/vi/$videoId/0.jpg',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildIconPlaceholder(),
        );
      }
    }

    return _buildIconPlaceholder();
  }
  // Widget _buildPlaceholder() {
  //   // Try to get YouTube thumbnail if no other image exists
  //   final String? videoPath = widget.lesson.videoUrl;
  //   if (videoPath != null &&
  //       (videoPath.contains('youtube.com') || videoPath.contains('youtu.be'))) {
  //     final String? videoId = _getYoutubeId(videoPath);
  //     if (videoId != null) {
  //       return Image.network(
  //         'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
  //         fit: BoxFit.cover,
  //         errorBuilder: (context, error, stackTrace) => _buildIconPlaceholder(),
  //       );
  //     }
  //   }

  //   return _buildIconPlaceholder();
  // }

  Widget _buildIconPlaceholder() {
    return Container(
      color: widget.isDark ? Colors.grey[900] : Colors.grey[200],
      child: Center(
        child: Icon(Icons.video_library, size: 50, color: Colors.grey[400]),
      ),
    );
  }

  Widget _buildSourceIndicator() {
    if (_isAudioOnly) {
      return Row(
        children: [
          Icon(Icons.headphones, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            "Audio Lesson",
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    if (_isYoutube) {
      return Row(
        children: [
          const Icon(FontAwesomeIcons.youtube, size: 14, color: Colors.grey),
          const SizedBox(width: 4),
          const Text('Online', style: TextStyle(color: Colors.grey)),
        ],
      );
    }

    if (widget.lesson.isLocal) {
      return Row(
        children: [
          Icon(Icons.sd_storage, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          const Text('Local file', style: TextStyle(color: Colors.grey)),
        ],
      );
    }

    return const SizedBox.shrink();
  }
}
