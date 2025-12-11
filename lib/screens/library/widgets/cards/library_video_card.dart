import 'dart:io';
import 'package:flutter/material.dart';
import 'package:linguaflow/screens/library/widgets/dialogs/library_actions.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/screens/reader/reader_screen.dart';

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
  Player? _player;
  VideoController? _controller;
  bool _isFrameReady = false;
  bool _isAudioOnly = false;

  @override
  void initState() {
    super.initState();
    _checkMediaTypeAndInit();
  }

  void _checkMediaTypeAndInit() {
    // 1. Check if it is explicitly marked as audio in your model
    if (widget.lesson.type == 'audio') {
      setState(() => _isAudioOnly = true);
      return;
    }
    
    // 2. Fallback: Check extension if type isn't set correctly
    final path = widget.lesson.videoUrl ?? "";
    final ext = path.toLowerCase();
    if (ext.endsWith('.mp3') || ext.endsWith('.wav') || ext.endsWith('.aac') || ext.endsWith('.m4a')) {
      setState(() => _isAudioOnly = true);
      return;
    }

    // 3. It's a video, generate thumbnail
    _initializeThumbnail();
  }

  Future<void> _initializeThumbnail() async {
    // FIX: Always check videoUrl first. Your import logic stores the file path there.
    String? videoPath = widget.lesson.videoUrl;
    
    // Fallback to content ONLY if videoUrl is empty (rare based on your code)
    if (videoPath == null || videoPath.isEmpty) {
      videoPath = widget.lesson.content;
    }

    if (videoPath == null || videoPath.isEmpty) return;

    // Check for YouTube
    final bool isYoutube = videoPath.toLowerCase().contains('youtube.com') || 
                           videoPath.toLowerCase().contains('youtu.be');

    // If it's YouTube, we don't use MediaKit (we use the image fetcher in build)
    if (isYoutube) return;

    // If Local, check if file exists
    if (widget.lesson.isLocal) {
       // Normalize path (remove file://)
       if (videoPath.startsWith('file://')) {
         videoPath = videoPath.replaceFirst('file://', '');
       }
       if (!File(videoPath).existsSync()) {
         debugPrint("File does not exist at: $videoPath");
         return;
       }
    }

    final player = Player();
    _player = player;

    final controller = VideoController(
      player,
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: true,
      ),
    );
    _controller = controller;

    try {
      await player.setVolume(0); 
      
      // Auto-play to force decoder
      await player.open(Media(videoPath), play: true);
      if (!mounted) return;

      // Wait for metadata
      await player.stream.width.firstWhere((w) => w != null && w > 0);
      if (!mounted) return;

      // Skip forward 1 second to avoid black fade-ins
      await player.seek(const Duration(milliseconds: 1000));
      if (!mounted) return;

      // Wait for render
      await controller.waitUntilFirstFrameRendered;
      if (!mounted) return;

      await player.pause();
      
      setState(() {
        _isFrameReady = true;
      });

    } catch (e) {
      debugPrint("Thumbnail generation error: $e");
    }
  }

  @override
  void dispose() {
    final player = _player;
    if (player != null) {
      player.dispose();
    }
    super.dispose();
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
          MaterialPageRoute(builder: (context) => ReaderScreen(lesson: widget.lesson)),
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
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: Container(
                    height: 140,
                    width: double.infinity,
                    color: widget.isDark ? Colors.black : Colors.grey[200],
                    child: _buildMediaContent(),
                  ),
                ),
                // Only show Play button overlay if it's NOT audio only (Audio has its own icon)
                if (!_isAudioOnly)
                  Positioned.fill(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.play_arrow, color: Colors.white, size: 24),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          widget.lesson.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: widget.isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => showLessonOptions(context, widget.lesson, widget.isDark),
                        child: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
                      ),
                    ],
                  ),
                  if (_isAudioOnly)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        "Audio Lesson",
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaContent() {
    // 1. Audio File -> Show Audio Icon
    if (_isAudioOnly) {
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

    // 2. Video Ready -> Show Video Frame
    if (_isFrameReady && _controller != null) {
      return Video(
        controller: _controller!,
        fit: BoxFit.cover,
        controls: NoVideoControls,
        pauseUponEnteringBackgroundMode: false,
      );
    }

    // 3. YouTube or Fallback -> Show Image or Icon
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    // Try explicit image URL
    if (widget.lesson.imageUrl != null && widget.lesson.imageUrl!.isNotEmpty) {
       return Image.network(widget.lesson.imageUrl!, fit: BoxFit.cover);
    }

    // Try YouTube Thumbnail
    final String? videoPath = widget.lesson.videoUrl;
    if (videoPath != null && (videoPath.contains('youtube.com') || videoPath.contains('youtu.be'))) {
      final String? videoId = _getYoutubeId(videoPath);
      if (videoId != null) {
        return Image.network(
          'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildIconPlaceholder(),
        );
      }
    }

    // Final Fallback
    return _buildIconPlaceholder();
  }

  Widget _buildIconPlaceholder() {
    return Container(
      color: widget.isDark ? Colors.grey[900] : Colors.grey[200],
      child: Center(
        child: Icon(
          Icons.video_library,
          size: 50,
          color: Colors.grey[400],
        ),
      ),
    );
  }
}