// lib/widgets/youtube_extractor_view.dart
import 'package:flutter/material.dart';
import 'package:linguaflow/services/youtube_import_service.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/models/transcript_line.dart';

class YoutubeExtractorView extends StatefulWidget {
  final String videoUrl;
  final String targetLang;
  final String userId;

  const YoutubeExtractorView({
    super.key,
    required this.videoUrl,
    required this.targetLang,
    required this.userId,
  });

  @override
  State<YoutubeExtractorView> createState() => _YoutubeExtractorViewState();
}

class _YoutubeExtractorViewState extends State<YoutubeExtractorView> {
  late final WebViewController _controller;
  final YoutubeParser _parser = YoutubeParser();
  bool _isExtracting = false;
  String _statusMessage = "Initializing Browser...";

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent("Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Mobile Safari/537.36")
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) async {
            setState(() => _statusMessage = "Waiting for YouTube data...");
            await Future.delayed(const Duration(seconds: 2)); 
            _extractData();
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.videoUrl));
  }

  Future<void> _extractData() async {
    if (_isExtracting) return;
    _isExtracting = true;
    setState(() => _statusMessage = "Extracting Subtitles...");

    try {
      final String result = await _controller.runJavaScriptReturningResult("""
        (function() {
          try {
             if (window.ytInitialPlayerResponse) {
                return JSON.stringify(window.ytInitialPlayerResponse);
             } 
             return "null";
          } catch (e) {
            return "error";
          }
        })();
      """) as String;

      if (result == '"null"' || result == "null") {
        throw Exception("YouTube Player Response not found. Video might be restricted.");
      }

      final extractedData = await _parser.processExtractedData(result, widget.targetLang);

      final lesson = LessonModel(
        id: '',
        userId: widget.userId,
        title: extractedData['title'],
        language: widget.targetLang,
        content: extractedData['fullContent'],
        sentences: (extractedData['fullContent'] as String).split('. '),
        transcript: extractedData['transcript'] as List<TranscriptLine>,
        createdAt: DateTime.now(),
        imageUrl: "https://img.youtube.com/vi/${_getVideoId(widget.videoUrl)}/mqdefault.jpg",
        type: 'video',
        difficulty: 'intermediate',
        videoUrl: widget.videoUrl,
        isFavorite: false,
        progress: 0,
      );

      if (mounted) {
        Navigator.pop(context, lesson);
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Extraction Failed: $e")),
        );
        Navigator.pop(context, null);
      }
    }
  }

  String _getVideoId(String url) {
    final uri = Uri.parse(url);
    if (uri.host.contains("youtu.be")) return uri.pathSegments.last;
    return uri.queryParameters['v'] ?? "";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: Stack(
        children: [
          Opacity(
            opacity: 0.01,
            child: SizedBox(
              height: 1, 
              width: 1,
              child: WebViewWidget(controller: _controller),
            ),
          ),
          
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: Colors.white),
                const SizedBox(height: 20),
                Text(
                  _statusMessage,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Please wait while we analyze the video...",
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}