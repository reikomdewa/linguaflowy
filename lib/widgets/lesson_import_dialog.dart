import 'dart:io';
import 'dart:typed_data'; // Added for Uint8List
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:linguaflow/utils/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

// --- MEDIA KIT ---
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart'; // Added for VideoController

import 'package:linguaflow/blocs/lesson/lesson_bloc.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/models/transcript_line.dart';
import 'package:linguaflow/services/lesson_service.dart';
import 'package:linguaflow/services/web_scraper_service.dart';
import 'package:linguaflow/utils/subtitle_parser.dart';

class LessonImportDialog {
  static void show(
    BuildContext context,
    String userId,
    String currentLanguage,
    Map<String, String> languageNames, {
    required bool isFavoriteByDefault,
    String? initialTitle,
    String? initialContent,
    // NEW PARAMS
    String? initialMediaUrl,
    int initialTabIndex = 0,
  }) {
    final lessonBloc = context.read<LessonBloc>();
    final lessonService = context.read<LessonService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fullLangName =
        languageNames[currentLanguage] ?? currentLanguage.toUpperCase();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _ImportDialogContent(
          userId: userId,
          currentLanguage: currentLanguage,
          fullLangName: fullLangName,
          isFavoriteByDefault: isFavoriteByDefault,
          initialTitle: initialTitle,
          initialContent: initialContent,
          initialMediaUrl: initialMediaUrl, // Pass through
          initialTabIndex: initialTabIndex, // Pass through
          lessonBloc: lessonBloc,
          lessonService: lessonService,
          isDark: isDark,
        );
      },
    );
  }
}

class _ImportDialogContent extends StatefulWidget {
  final String userId;
  final String currentLanguage;
  final String fullLangName;
  final bool isFavoriteByDefault;
  final String? initialTitle;
  final String? initialContent;
  final String? initialMediaUrl; // NEW
  final int initialTabIndex; // NEW
  final LessonBloc lessonBloc;
  final LessonService lessonService;
  final bool isDark;

  const _ImportDialogContent({
    required this.userId,
    required this.currentLanguage,
    required this.fullLangName,
    required this.isFavoriteByDefault,
    this.initialTitle,
    this.initialContent,
    this.initialMediaUrl,
    this.initialTabIndex = 0,
    required this.lessonBloc,
    required this.lessonService,
    required this.isDark,
  });

  @override
  State<_ImportDialogContent> createState() => _ImportDialogContentState();
}

class _ImportDialogContentState extends State<_ImportDialogContent>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  late TextEditingController _titleController;
  late TextEditingController _contentController;
  final _webUrlController = TextEditingController();

  late TextEditingController
  _mediaUrlController; // Changed to late to init in initState
  File? _selectedMediaFile;
  File? _selectedSubtitleFile;

  String? _previewSubtitleText;
  bool _isLoading = false;
  String? _errorMsg;
  String? _mediaWarningMsg;

  @override
  void initState() {
    super.initState();
    try {
      MediaKit.ensureInitialized();
    } catch (_) {}

    // Initialize TabController with the passed index (0 for Text, 1 for Media)
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );

    _titleController = TextEditingController(text: widget.initialTitle ?? '');
    _contentController = TextEditingController(
      text: widget.initialContent ?? '',
    );

    // Initialize Media Controller with passed URL if any
    _mediaUrlController = TextEditingController(
      text: widget.initialMediaUrl ?? '',
    );

    // Run the check immediately if we have a URL
    if (widget.initialMediaUrl != null && widget.initialMediaUrl!.isNotEmpty) {
      _checkYoutubeLink();
    }

    _mediaUrlController.addListener(_checkYoutubeLink);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    _webUrlController.dispose();
    _mediaUrlController.dispose();
    super.dispose();
  }

  void _checkYoutubeLink() {
    final text = _mediaUrlController.text.toLowerCase();
    if (text.contains('youtube.com') || text.contains('youtu.be')) {
      setState(() {
        _mediaWarningMsg =
            "YouTube detected. Use downsub.com to get .srt subtitles.";
      });
    } else {
      if (_mediaWarningMsg != null &&
          _mediaWarningMsg!.contains('downsub.com')) {
        setState(() => _mediaWarningMsg = null);
      }
    }
  }

  // --- Web Scraper ---
  Future<void> _handleWebImport() async {
    final url = _webUrlController.text.trim();
    if (url.isEmpty) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    final data = await WebScraperService.scrapeUrl(url);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (data != null) {
          _titleController.text = data['title'] ?? "";
          _contentController.text = data['content'] ?? "";
          _webUrlController.clear();
        } else {
          _errorMsg = "Could not extract text. Check the URL.";
        }
      });
    }
  }

  // --- Local Media Picker ---
  Future<void> _pickMediaFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'mp4',
        'mov',
        'avi',
        'mkv',
        'mp3',
        'wav',
        'm4a',
        'aac',
        'flac',
      ],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedMediaFile = File(result.files.single.path!);
        _mediaUrlController.clear();
        _mediaWarningMsg = null;

        if (_titleController.text.isEmpty) {
          _titleController.text = path.basenameWithoutExtension(
            _selectedMediaFile!.path,
          );
        }
      });
      _validateDuration();
    }
  }

  Future<void> _pickSubtitleFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['srt', 'vtt'],
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      try {
        final content = await file.readAsString();
        final cleanText = _extractTextNaive(content);
        setState(() {
          _selectedSubtitleFile = file;
          _previewSubtitleText = cleanText;
        });
        _validateDuration();
      } catch (e) {
        setState(() => _errorMsg = "Failed to read subtitle file.");
      }
    }
  }

  // --- Validation ---
  Future<void> _validateDuration() async {
    if (_selectedMediaFile == null || _selectedSubtitleFile == null) return;
    setState(() => _isLoading = true);

    try {
      final player = Player();
      await player.open(Media(_selectedMediaFile!.path), play: false);

      // Using timeout to prevent stuck logic here too
      try {
        await player.stream.duration
            .firstWhere((d) => d != Duration.zero)
            .timeout(const Duration(seconds: 2));
      } catch (_) {
        // Continue if duration check times out
      }

      Duration mediaDuration = player.state.duration;
      await player.dispose();

      final subContent = await _selectedSubtitleFile!.readAsString();
      final lastTimestamp = _getLastSubtitleTimestamp(subContent);

      if (mediaDuration.inSeconds > 0 && lastTimestamp != Duration.zero) {
        final diff = (mediaDuration.inSeconds - lastTimestamp.inSeconds).abs();
        if (diff > 20) {
          setState(() {
            _mediaWarningMsg =
                "Warning: Subtitle length (${_formatDuration(lastTimestamp)}) differs from media (${_formatDuration(mediaDuration)}).";
          });
        } else {
          setState(() => _mediaWarningMsg = null);
        }
      }
    } catch (e) {
      printLog("Validation error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- FIXED: Thumbnail Generation Helper ---
  Future<String?> _generateThumbnail(String videoPath, String targetDir) async {
    final player = Player();
    // FIX 1: Initialize VideoController.
    // This forces media_kit to set up the rendering pipeline (textures),
    // which makes screenshotting much more reliable even if not displayed.
    final controller = VideoController(player);

    try {
      await player.setVolume(0);
      await player.open(Media(videoPath), play: false);

      // FIX 2: Add timeouts. If the video is corrupt or weird, we shouldn't hang forever.
      try {
        // Wait for video dimensions
        await player.stream.width
            .firstWhere((w) => w != null && w > 0)
            .timeout(const Duration(seconds: 2));
      } catch (_) {
        printLog("Timeout waiting for video width");
        return null;
      }

      // Seek to 1 second
      await player.seek(const Duration(seconds: 1));

      // Wait a bit for the frame to decode
      await Future.delayed(const Duration(milliseconds: 500));

      // FIX 3: Add timeout to the actual screenshot command
      final Uint8List? bytes = await player
          .screenshot(format: 'image/jpeg')
          .timeout(const Duration(seconds: 3));

      if (bytes != null) {
        final String imagePath = '$targetDir/thumbnail.jpg';
        await File(imagePath).writeAsBytes(bytes);
        return imagePath;
      }
    } catch (e) {
      debugPrint("Error generating thumbnail: $e");
    } finally {
      // Always dispose
      await player.dispose();
    }
    return null;
  }

  // --- Creation Logic ---
  Future<void> _createLesson() async {
    if (_titleController.text.isEmpty) {
      setState(() => _errorMsg = "Title is required");
      return;
    }

    String finalContent = "";
    String type = "text";
    String? localMediaPath;
    String? localSubtitlePath;
    String? localImagePath;
    List<TranscriptLine> finalTranscript = [];

    if (_tabController.index == 0) {
      // TEXT TAB
      finalContent = _contentController.text;
      if (finalContent.isEmpty) {
        setState(() => _errorMsg = "Content is required");
        return;
      }
    } else {
      // MEDIA TAB
      if (_selectedSubtitleFile == null) {
        setState(() => _errorMsg = "Subtitle file is required.");
        return;
      }

      setState(() => _isLoading = true);

      try {
        final appDir = await getApplicationDocumentsDirectory();
        final String dirPath =
            '${appDir.path}/lessons/${DateTime.now().millisecondsSinceEpoch}';
        await Directory(dirPath).create(recursive: true);

        // Handle Media
        if (_selectedMediaFile != null) {
          final ext = path.extension(_selectedMediaFile!.path).toLowerCase();

          if (['.mp3', '.wav', '.m4a', '.aac', '.flac', '.ogg'].contains(ext)) {
            type = "audio";
          } else {
            type = "video";
            // Attempt to generate thumbnail, but don't crash if it fails
            try {
              localImagePath = await _generateThumbnail(
                _selectedMediaFile!.path,
                dirPath,
              );
            } catch (e) {
              printLog("Skipping thumbnail: $e");
            }
          }

          final String newMediaPath = '$dirPath/media$ext';
          await _selectedMediaFile!.copy(newMediaPath);
          localMediaPath = newMediaPath;
        } else if (_mediaUrlController.text.isNotEmpty) {
          type = "video";
          localMediaPath = _mediaUrlController.text;
        } else {
          throw Exception("Media file or URL is required.");
        }

        // Handle Subtitle
        final String newSubPath =
            '$dirPath/subs${path.extension(_selectedSubtitleFile!.path)}';
        await _selectedSubtitleFile!.copy(newSubPath);
        localSubtitlePath = newSubPath;

        // Parse Transcript
        try {
          finalTranscript = await SubtitleParser.parseFile(newSubPath);
          if (finalTranscript.isNotEmpty) {
            finalContent = finalTranscript.map((t) => t.text).join(" ");
          } else {
            finalContent = await _selectedSubtitleFile!.readAsString();
          }
        } catch (e) {
          printLog("Error parsing transcript: $e");
          finalContent = await _selectedSubtitleFile!.readAsString();
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMsg = "Failed to import files: $e";
          });
        }
        return;
      }
    }

    final sentences = widget.lessonService.splitIntoSentences(finalContent);

    final lesson = LessonModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: widget.userId,
      title: _titleController.text,
      language: widget.currentLanguage,
      content: finalContent,
      sentences: sentences,
      transcript: finalTranscript,
      createdAt: DateTime.now(),
      progress: 0,
      isFavorite: widget.isFavoriteByDefault,
      type: type,
      videoUrl: localMediaPath,
      subtitleUrl: localSubtitlePath,
      imageUrl: localImagePath,
      isLocal: true,
    );

    widget.lessonBloc.add(LessonCreateRequested(lesson));

    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.pop(context);
    }
  }

  // --- Widgets ---
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: widget.isDark ? const Color(0xFF1E1E1E) : Colors.white,
      contentPadding: EdgeInsets.zero,
      title: Column(
        children: [
          Text(
            'Create Lesson (${widget.fullLangName})',
            style: TextStyle(
              color: widget.isDark ? Colors.white : Colors.black,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 10),
          TabBar(
            controller: _tabController,
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue,
            tabs: const [
              Tab(icon: Icon(Icons.article_outlined), text: "Text"),
              Tab(icon: Icon(Icons.perm_media_outlined), text: "Media"),
            ],
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: TabBarView(
          controller: _tabController,
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWebImportSection(),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  _buildStandardFields(),
                ],
              ),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMediaSection(),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _titleController,
                    style: TextStyle(
                      color: widget.isDark ? Colors.white : Colors.black,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Lesson Title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _createLesson,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }

  Widget _buildWebImportSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Import from Web",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _webUrlController,
                  style: TextStyle(
                    color: widget.isDark ? Colors.white : Colors.black,
                    fontSize: 13,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Paste URL...',
                    isDense: true,
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _isLoading ? null : _handleWebImport,
                icon: const Icon(Icons.download_rounded, color: Colors.blue),
              ),
            ],
          ),
          if (_errorMsg != null && _tabController.index == 0)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                _errorMsg!,
                style: const TextStyle(color: Colors.red, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStandardFields() {
    return Column(
      children: [
        TextField(
          controller: _titleController,
          style: TextStyle(color: widget.isDark ? Colors.white : Colors.black),
          decoration: const InputDecoration(
            labelText: 'Title',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _contentController,
          style: TextStyle(color: widget.isDark ? Colors.white : Colors.black),
          decoration: const InputDecoration(
            labelText: 'Content',
            border: OutlineInputBorder(),
          ),
          maxLines: 10,
          minLines: 4,
        ),
      ],
    );
  }

  Widget _buildMediaSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Media Source",
          style: TextStyle(
            color: widget.isDark ? Colors.grey : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _mediaUrlController,
          enabled: _selectedMediaFile == null,
          style: TextStyle(color: widget.isDark ? Colors.white : Colors.black),
          decoration: InputDecoration(
            hintText: 'Paste YouTube URL...',
            prefixIcon: const Icon(Icons.link),
            border: const OutlineInputBorder(),
            suffixIcon: _mediaUrlController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => _mediaUrlController.clear(),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 10),
        const Center(
          child: Text(
            "- OR -",
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ),
        const SizedBox(height: 10),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              if (_selectedMediaFile != null) ...[
                Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        path.basename(_selectedMediaFile!.path),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: widget.isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => setState(() {
                        _selectedMediaFile = null;
                        _mediaWarningMsg = null;
                      }),
                    ),
                  ],
                ),
              ] else ...[
                OutlinedButton.icon(
                  onPressed: _mediaUrlController.text.isEmpty
                      ? _pickMediaFile
                      : null,
                  icon: const Icon(Icons.perm_media),
                  label: const Text("Select Video/Audio File"),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 20),
        Text(
          "Subtitles (.srt / .vtt)",
          style: TextStyle(
            color: widget.isDark ? Colors.grey : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(8),
            color: widget.isDark ? Colors.black12 : Colors.grey.shade50,
          ),
          child: Column(
            children: [
              if (_selectedSubtitleFile != null) ...[
                Row(
                  children: [
                    const Icon(Icons.subtitles, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        path.basename(_selectedSubtitleFile!.path),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: widget.isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.grey),
                      onPressed: _pickSubtitleFile,
                    ),
                  ],
                ),
                if (_previewSubtitleText != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      "Preview: ${_previewSubtitleText!.length} chars found.",
                      style: const TextStyle(fontSize: 11, color: Colors.green),
                    ),
                  ),
              ] else ...[
                OutlinedButton.icon(
                  onPressed: _pickSubtitleFile,
                  icon: const Icon(Icons.closed_caption),
                  label: const Text("Upload Subtitle File"),
                ),
              ],
            ],
          ),
        ),

        if (_mediaWarningMsg != null)
          Container(
            margin: const EdgeInsets.only(top: 15),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _mediaWarningMsg!,
                    style: TextStyle(
                      fontSize: 12,
                      color: widget.isDark
                          ? Colors.orange.shade200
                          : Colors.orange.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),

        if (_errorMsg != null && _tabController.index == 1)
          Padding(
            padding: const EdgeInsets.only(top: 10.0),
            child: Text(
              _errorMsg!,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ),
      ],
    );
  }

  String _formatDuration(Duration d) =>
      "${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}";

  String _extractTextNaive(String fileContent) {
    final lines = fileContent.split('\n');
    final buffer = StringBuffer();
    final timePattern = RegExp(r'\d{2}:\d{2}:\d{2}');
    for (var line in lines) {
      String l = line.trim();
      if (l.isEmpty ||
          int.tryParse(l) != null ||
          (l.contains('-->') && timePattern.hasMatch(l))) {
        continue;
      }
      buffer.writeln(l.replaceAll(RegExp(r'<[^>]*>'), ''));
    }
    return buffer.toString();
  }

  Duration _getLastSubtitleTimestamp(String fileContent) {
    final regex = RegExp(r'(?:(\d{1,2}):)?(\d{1,2}):(\d{2})[,.](\d{3})');
    final matches = regex.allMatches(fileContent);
    if (matches.isEmpty) return Duration.zero;
    final lastMatch = matches.last;

    int h = lastMatch.group(1) != null ? int.parse(lastMatch.group(1)!) : 0;
    int m = int.parse(lastMatch.group(2)!);
    int s = int.parse(lastMatch.group(3)!);

    return Duration(hours: h, minutes: m, seconds: s);
  }
}
