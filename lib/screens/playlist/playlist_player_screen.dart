
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:audio_session/audio_session.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

// --- Internal App Imports ---
import 'package:linguaflow/screens/reader/utils/media_lifecycle.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/models/vocabulary_item.dart';
import 'package:linguaflow/models/transcript_line.dart';
import 'package:linguaflow/services/translation_service.dart';
import 'package:linguaflow/utils/subtitle_parser.dart';
import 'package:linguaflow/screens/reader/reader_utils.dart';
import 'package:linguaflow/screens/reader/widgets/interactive_text_display.dart';

class PlaylistPlayerScreen extends StatefulWidget {
  final List<LessonModel> playlist;
  final int initialIndex;

  const PlaylistPlayerScreen({
    super.key,
    required this.playlist,
    this.initialIndex = 0,
  });

  @override
  _PlaylistPlayerScreenState createState() => _PlaylistPlayerScreenState();
}

class _PlaylistPlayerScreenState extends State<PlaylistPlayerScreen>
    with WidgetsBindingObserver {
  // --- Playlist State ---
  late int _currentIndex;
  late LessonModel _currentLesson;
  bool _isChangingTrack = false;

  // --- Data & Config ---
  Map<String, VocabularyItem> _vocabulary = {};

  // Media Players
  YoutubePlayerController? _youtubeController;
  Player? _localPlayer;
  VideoController? _localVideoController;

  // Timers & Trackers
  Timer? _syncTimer;
  Timer? _listeningTrackingTimer;
  int _secondsListenedInSession = 0;

  // --- Media State ---
  bool _isVideo = false;
  bool _isAudio = false;
  bool _isYoutubeAudio = false;
  bool _isLocalMedia = false;
  bool _isPlaying = false;
  bool _isSeeking = false;

  // Subtitles / Text
  List<String> _smartChunks = [];
  List<TranscriptLine> _activeTranscript = [];
  int _activeSentenceIndex = -1;
  final ScrollController _listScrollController = ScrollController();
  List<GlobalKey> _itemKeys = [];

  // Translation / Dictionary
  bool _showCard = false;
  String? _googleTranslation;
  bool _isLoadingTranslation = false;
  String _selectedText = "";
  String _selectedCleanId = "";
  Future<String>? _cardTranslationFuture;

  // TTS Fallback
  final FlutterTts _flutterTts = FlutterTts();

  late AuthBloc _authBloc;

  @override
  void initState() {
    super.initState();
    _authBloc = context.read<AuthBloc>();
    WidgetsBinding.instance.addObserver(this);

    _currentIndex = widget.initialIndex;
    _initGemini();
    _loadVocabulary();
    _configureAudioSession();

    // Start the first lesson
    _loadCurrentLesson();
  }

  Future<void> _configureAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
  }

  /// Loads the lesson at _currentIndex
  void _loadCurrentLesson() async {
    // 1. Update UI immediately to show loading state and new title
    setState(() {
      _isChangingTrack = true;
      _currentLesson = widget.playlist[_currentIndex];
      _activeTranscript = _currentLesson.transcript;
      _activeSentenceIndex = -1;
      _isPlaying = false;
      _googleTranslation = null;
      _showCard = false;
    });

    // Reset Scroll Position
    if (_listScrollController.hasClients) {
      _listScrollController.jumpTo(0);
    }

    try {
      // 2. Parse Subtitles (if needed and not already parsed)
      if ((_currentLesson.subtitleUrl != null &&
              _currentLesson.subtitleUrl!.isNotEmpty) &&
          _activeTranscript.isEmpty) {
        try {
          final lines = await SubtitleParser.parseFile(
            _currentLesson.subtitleUrl!,
          );
          if (mounted) _activeTranscript = lines;
        } catch (e) {
          debugPrint("Error parsing subs: $e");
        }
      }

      // 3. Prepare Text Chunks
      _generateSmartChunks();
      _itemKeys = List.generate(_smartChunks.length, (_) => GlobalKey());

      // 4. Initialize Media
      await _initializeMedia();

      // 5. Ready to play
      if (mounted) {
        setState(() => _isChangingTrack = false);
        _playMedia();
      }
    } catch (e) {
      debugPrint("CRITICAL ERROR LOADING LESSON: $e");
      // Ensure UI doesn't get stuck in loading state even if media fails
      if (mounted) {
        setState(() => _isChangingTrack = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading track: $e")),
        );
      }
    }
  }

  void _generateSmartChunks() {
    _smartChunks = [];
    if (_activeTranscript.isNotEmpty) {
      for (var t in _activeTranscript) {
        _smartChunks.add(t.text);
      }
      return;
    }
    List<String> rawSentences = _currentLesson.sentences;
    if (rawSentences.isEmpty) {
      rawSentences = _currentLesson.content.split(RegExp(r'(?<=[.!?])\s+'));
    }
    for (String sentence in rawSentences) {
      if (sentence.trim().isNotEmpty) _smartChunks.add(sentence.trim());
    }
  }

  Future<void> _initializeMedia() async {
    // Stop and cleanup old player first
    _disposePlayers();

    final url = _currentLesson.videoUrl;

    // Fallback to TTS if no media URL
    if (url == null || url.isEmpty) {
      await _flutterTts.setLanguage(_currentLesson.language);
      if (mounted) {
        setState(() {
          _isAudio = false;
          _isVideo = false;
          _isYoutubeAudio = false;
        });
      }
      return;
    }

    bool isYoutube = url.toLowerCase().contains('youtube.com') ||
        url.toLowerCase().contains('youtu.be');

    // Determine Type
    bool isVid = true;
    bool isAud = false;
    bool isYtAud = false;

    if (_currentLesson.id.startsWith('yt_audio_') ||
        (isYoutube && _currentLesson.type == 'audio')) {
      isYtAud = true;
      isVid = false;
    } else if (_currentLesson.type == 'audio' ||
        ['mp3', 'wav', 'm4a'].any((ext) => url.endsWith(ext))) {
      isAud = true;
      isVid = false;
    }

    if (mounted) {
      setState(() {
        _isVideo = isVid;
        _isAudio = isAud;
        _isYoutubeAudio = isYtAud;
      });
    }

    if (isYoutube) {
      String? videoId = YoutubePlayer.convertUrlToId(url);
      if (videoId != null) {
        _youtubeController = YoutubePlayerController(
          initialVideoId: videoId,
          flags: const YoutubePlayerFlags(
            autoPlay: true,
            hideControls: true,
            enableCaption: false,
          ),
        );
        if (mounted) {
          setState(() => _isLocalMedia = false);
          _startSyncTimer();
        }
      }
    } else {
      // MEDIA KIT
      _localPlayer = Player();
      _localVideoController = VideoController(_localPlayer!);

      // Important for Android background audio
      if (Platform.isAndroid) {
         // _localPlayer!.setPlaylistMode(PlaylistMode.none);
      }

      await _localPlayer!.open(Media(url), play: false);
      if (mounted) {
        setState(() => _isLocalMedia = true);
        _startSyncTimer();
      }
    }
  }

  void _disposePlayers() {
    _syncTimer?.cancel();
    _youtubeController?.dispose();
    _youtubeController = null;

    _localVideoController = null;

    if (_localPlayer != null) {
      MediaLifecycle.disposeSafe(_localPlayer);
      _localPlayer = null;
    }
  }

  @override
  void dispose() {
    _stopListeningTracker();

    if (_secondsListenedInSession > 10) {
      final int minutes = (_secondsListenedInSession / 60).ceil();
      _authBloc.add(AuthUpdateListeningTime(minutes));
    }

    WidgetsBinding.instance.removeObserver(this);
    _disposePlayers();
    _flutterTts.stop();
    _listScrollController.dispose();
    super.dispose();
  }

  // --- PLAYBACK CONTROLS ---

  void _playNext() {
    if (_currentIndex < widget.playlist.length - 1) {
      context.read<AuthBloc>().add(AuthIncrementLessonsCompleted());
      setState(() => _currentIndex++);
      _loadCurrentLesson();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Playlist Completed!")),
        );
      }
    }
  }

  void _playPrev() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _loadCurrentLesson();
    }
  }

  void _playMedia() {
    if (_isLocalMedia && _localPlayer != null) {
      _localPlayer!.play();
    } else {
      _youtubeController?.play();
    }
    _startListeningTracker();
  }

  void _pauseMedia() {
    if (_isLocalMedia && _localPlayer != null) {
      _localPlayer!.pause();
    } else {
      _youtubeController?.pause();
    }
    _stopListeningTracker();
  }

  void _togglePlayback() {
    if (_isPlaying) {
      _pauseMedia();
    } else {
      _playMedia();
    }
  }

  // --- SYNC ENGINE ---
  void _startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => _checkSync(),
    );
  }

  void _checkSync() {
    if (_isSeeking || _isChangingTrack) return;

    bool isPlaying = false;
    double currentSeconds = 0.0;
    double totalDuration = 0.0;

    if (_isLocalMedia && _localPlayer != null) {
      isPlaying = _localPlayer!.state.playing;
      currentSeconds = _localPlayer!.state.position.inMilliseconds / 1000.0;
      totalDuration = _localPlayer!.state.duration.inSeconds.toDouble();
    } else if (_youtubeController != null) {
      isPlaying = _youtubeController!.value.isPlaying;
      currentSeconds =
          _youtubeController!.value.position.inMilliseconds / 1000.0;
      totalDuration =
          _youtubeController!.metadata.duration.inSeconds.toDouble();
    }

    if (isPlaying != _isPlaying) {
      setState(() => _isPlaying = isPlaying);
    }

    // Auto-Advance Logic
    if (totalDuration > 0 && currentSeconds >= totalDuration - 1.5) {
      _playNext();
      return;
    }

    if (_activeTranscript.isNotEmpty) {
      int activeIndex = -1;
      for (int i = 0; i < _activeTranscript.length; i++) {
        if (currentSeconds >= _activeTranscript[i].start &&
            currentSeconds < _activeTranscript[i].end) {
          activeIndex = i;
          break;
        }
      }
      if (activeIndex == -1 && currentSeconds > 0) {
        for (int i = 0; i < _activeTranscript.length; i++) {
          if (_activeTranscript[i].start > currentSeconds) {
            activeIndex = i > 0 ? i - 1 : 0;
            break;
          }
        }
      }

      if (activeIndex != -1 && activeIndex != _activeSentenceIndex) {
        setState(() => _activeSentenceIndex = activeIndex);
        _scrollToActiveLine(activeIndex);
      }
    }
  }

  void _scrollToActiveLine(int index) {
    if (index >= 0 &&
        index < _itemKeys.length &&
        _itemKeys[index].currentContext != null) {
      Scrollable.ensureVisible(
        _itemKeys[index].currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.5,
      );
    }
  }

  void _loadVocabulary() {
    // Implement vocabulary loading if needed
  }

  void _initGemini() {
    final envKey = dotenv.env['GEMINI_API_KEY'];
    if (envKey != null && envKey.isNotEmpty) Gemini.init(apiKey: envKey);
  }

  void _startListeningTracker() {
    _listeningTrackingTimer?.cancel();
    _listeningTrackingTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _secondsListenedInSession++,
    );
  }

  void _stopListeningTracker() => _listeningTrackingTimer?.cancel();

  // --- UI BUILDING ---
  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      appBar: AppBar(
        title: Column(
          children: [
            const Text(
              "Now Playing",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            Text(
              "Track ${_currentIndex + 1} of ${widget.playlist.length}",
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.playlist_play),
            onPressed: _showPlaylistBottomSheet,
          ),
        ],
      ),
      // --- FIX 1: SAFE AREA & STACK STRUCTURE ---
      body: SafeArea(
        top: false, // Don't cut off video at top
        bottom: false, // We'll handle bottom padding manually or via sub-SafeArea
        child: Stack(
          children: [
            Column(
              children: [
                // 1. MEDIA AREA (Video/Audio)
                // We keep this OUT of SafeArea so video touches top edge
                if (_isVideo || _isAudio || _isYoutubeAudio)
                  Container(
                    height: _isVideo ? 220 : 0,
                    width: double.infinity,
                    color: Colors.black,
                    child: _isVideo ? _buildSharedPlayer() : null,
                  ),

                // 2. CONTENT AREA (Rest of the screen)
                Expanded(
                  child: SafeArea(
                    top: false, // Already below video
                    child: Column(
                      children: [
                        // A. THUMBNAIL (For Audio Mode)
                        if (!_isVideo)
                          Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Container(
                              width: 150,
                              height: 150,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  const BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 10,
                                  ),
                                ],
                                image: DecorationImage(
                                  image: _currentLesson.imageUrl != null &&
                                          _currentLesson.imageUrl!.isNotEmpty
                                      ? NetworkImage(_currentLesson.imageUrl!)
                                      : const AssetImage(
                                              'assets/images/placeholder_audio.png')
                                          as ImageProvider,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),

                        // B. LESSON INFO
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            children: [
                              Text(
                                _currentLesson.title,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                              ),
                              const SizedBox(height: 5),
                              Text(
                                _currentLesson.language,
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),

                        const Divider(),

                        // C. TRANSCRIPT
                        Expanded(
                          child: _isChangingTrack
                              ? const Center(child: CircularProgressIndicator())
                              : _smartChunks.isEmpty
                                  ? const Center(
                                      child: Text("No transcript available"))
                                  : ListView.separated(
                                      controller: _listScrollController,
                                      padding: const EdgeInsets.all(20),
                                      itemCount: _smartChunks.length,
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(height: 12),
                                      itemBuilder: (context, index) {
                                        final isActive =
                                            index == _activeSentenceIndex;
                                        return InteractiveTextDisplay(
                                          key: _itemKeys[index],
                                          text: _smartChunks[index],
                                          sentenceIndex: index,
                                          vocabulary: _vocabulary,
                                          onWordTap: (word, cleanId, pos) {
                                            _showDictionary(word, cleanId);
                                          },
                                          onPhraseSelected:
                                              (phrase, pos, clear) {
                                            _showDictionary(
                                              phrase,
                                              ReaderUtils.generateCleanId(
                                                  phrase),
                                            );
                                          },
                                          isBigMode: isActive,
                                          isListeningMode: false,
                                          isOverlay: false,
                                      
                                        );
                                      },
                                    ),
                        ),

                        // D. CONTROLS
                        _buildPlayerControls(),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            if (_showCard)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildDictionarySheet(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSharedPlayer() {
    if (_isLocalMedia && _localVideoController != null) {
      return Video(controller: _localVideoController!);
    } else if (_youtubeController != null) {
      return YoutubePlayer(controller: _youtubeController!);
    }
    return const SizedBox.shrink();
  }

  Widget _buildPlayerControls() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // PREV
          IconButton(
            icon: const Icon(Icons.skip_previous, size: 32),
            onPressed:
                _currentIndex > 0 ? _playPrev : null, // Disable if first
            color: _currentIndex > 0 ? null : Colors.grey,
          ),
          // REWIND
          IconButton(
            icon: const Icon(Icons.replay_10),
            onPressed: () {
              if (_localPlayer != null) {
                _localPlayer!.seek(
                  _localPlayer!.state.position - const Duration(seconds: 10),
                );
              }
              if (_youtubeController != null) {
                _youtubeController!.seekTo(
                  _youtubeController!.value.position -
                      const Duration(seconds: 10),
                );
              }
            },
          ),
          // PLAY/PAUSE
          FloatingActionButton(
            backgroundColor: Theme.of(context).primaryColor,
            onPressed: _togglePlayback,
            child: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
          ),
          // FORWARD
          IconButton(
            icon: const Icon(Icons.forward_10),
            onPressed: () {
              if (_localPlayer != null) {
                _localPlayer!.seek(
                  _localPlayer!.state.position + const Duration(seconds: 10),
                );
              }
              if (_youtubeController != null) {
                _youtubeController!.seekTo(
                  _youtubeController!.value.position +
                      const Duration(seconds: 10),
                );
              }
            },
          ),
          // NEXT
          IconButton(
            icon: const Icon(Icons.skip_next, size: 32),
            onPressed: _currentIndex < widget.playlist.length - 1
                ? _playNext
                : null,
            color: _currentIndex < widget.playlist.length - 1
                ? null
                : Colors.grey,
          ),
        ],
      ),
    );
  }

  void _showPlaylistBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  "Up Next",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: widget.playlist.length,
                  itemBuilder: (context, index) {
                    final item = widget.playlist[index];
                    final isCurrent = index == _currentIndex;
                    return ListTile(
                      selected: isCurrent,
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: item.imageUrl != null
                            ? Image.network(
                                item.imageUrl!,
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                width: 50,
                                height: 50,
                                color: Colors.grey,
                              ),
                      ),
                      title: Text(item.title, maxLines: 1),
                      subtitle: Text(item.language),
                      trailing: isCurrent
                          ? const Icon(Icons.equalizer, color: Colors.blue)
                          : null,
                      onTap: () {
                        Navigator.pop(context);
                        if (index != _currentIndex) {
                          setState(() => _currentIndex = index);
                          _loadCurrentLesson();
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- DICTIONARY ---
  void _showDictionary(String text, String cleanId) {
    if (_isPlaying) _pauseMedia();
    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
    final svc = context.read<TranslationService>();

    setState(() {
      _showCard = true;
      _selectedText = text;
      _selectedCleanId = cleanId;
      _isLoadingTranslation = true;
      _cardTranslationFuture = svc
          .translate(text, user.nativeLanguage, _currentLesson.language)
          .then((v) => v ?? "");
    });
  }

  Widget _buildDictionarySheet() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF2C2C2C) : Colors.white;
    final txt = isDark ? Colors.white : Colors.black;

    return Container(
      height: 250,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [const BoxShadow(blurRadius: 10, color: Colors.black26)],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedText,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: txt,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _showCard = false),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 10),
            FutureBuilder<String>(
              future: _cardTranslationFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) return const Text("Error loading");
                return Text(
                  snapshot.data ?? "No translation",
                  style: TextStyle(fontSize: 18, color: txt),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}