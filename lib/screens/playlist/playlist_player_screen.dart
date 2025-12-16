import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:audio_session/audio_session.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

// --- Internal App Imports ---
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/models/lesson_model.dart';
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

  // --- Players ---
  YoutubePlayerController? _youtubeController;
  final AudioPlayer _audioPlayer = AudioPlayer();

  // --- Timers & Trackers ---
  Timer? _syncTimer;
  Timer? _listeningTrackingTimer;
  int _secondsListenedInSession = 0;

  // --- Media State ---
  bool _isYoutube = false;
  bool _isPlaying = false;

  // Progress Bar State
  bool _isSeeking = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  // Subtitles / Text
  List<String> _smartChunks = [];
  List<TranscriptLine> _activeTranscript = [];
  int _activeSentenceIndex = -1;
  final ScrollController _listScrollController = ScrollController();
  List<GlobalKey> _itemKeys = [];

  // Translation / Dictionary
  bool _showCard = false;
  String _selectedText = "";
  String _selectedCleanId = "";
  Future<String>? _cardTranslationFuture;

  // TTS Fallback
  final FlutterTts _flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentIndex = widget.initialIndex;
    _initGemini();
    _configureAudioSession();

    // Start First Lesson
    _loadCurrentLesson();
  }

  Future<void> _configureAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
  }

  // --- LOAD LOGIC ---

  void _loadCurrentLesson() async {
    setState(() {
      _isChangingTrack = true;
      _currentLesson = widget.playlist[_currentIndex];
      _activeTranscript = _currentLesson.transcript;
      _activeSentenceIndex = -1;
      _isPlaying = false;
      _currentPosition = Duration.zero;
      _totalDuration = Duration.zero;
      _showCard = false;
    });

    if (_listScrollController.hasClients) {
      _listScrollController.jumpTo(0);
    }

    try {
      // 1. Initial Content Generation (Fallback)
      _generateSmartChunks();

      // 2. Parse Subtitles (Async)
      if ((_currentLesson.subtitleUrl?.isNotEmpty ?? false) &&
          _activeTranscript.isEmpty) {
        SubtitleParser.parseFile(_currentLesson.subtitleUrl!)
            .then((lines) {
              if (mounted) {
                setState(() {
                  _activeTranscript = lines;
                  _generateSmartChunks();
                  _itemKeys = List.generate(
                    _smartChunks.length,
                    (_) => GlobalKey(),
                  );
                });
              }
            })
            .catchError((e) {
              debugPrint("Subtitle parse error: $e");
            });
      } else {
        _itemKeys = List.generate(_smartChunks.length, (_) => GlobalKey());
      }

      // 3. Initialize Media
      await _initializeMedia();

      if (mounted) {
        setState(() => _isChangingTrack = false);
        _startListeningTracker();
      }
    } catch (e) {
      debugPrint("Error loading lesson: $e");
      if (mounted) setState(() => _isChangingTrack = false);
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
    List<String> raw = _currentLesson.sentences;
    if (raw.isEmpty) {
      raw = _currentLesson.content.split(RegExp(r'(?<=[.!?])\s+'));
    }
    for (String s in raw) {
      if (s.trim().isNotEmpty) _smartChunks.add(s.trim());
    }
  }

  Future<void> _initializeMedia() async {
    final url = _currentLesson.videoUrl;

    // A. Fallback to TTS
    if (url == null || url.isEmpty) {
      _disposeMediaControllers();
      await _flutterTts.setLanguage(_currentLesson.language);
      if (mounted) {
        setState(() {
          _isYoutube = false;
        });
      }
      return;
    }

    bool isYt =
        url.toLowerCase().contains('youtube.com') ||
        url.toLowerCase().contains('youtu.be');

    if (mounted) {
      setState(() {
        _isYoutube = isYt;
      });
    }

    if (isYt) {
      // --- YOUTUBE MODE ---
      await _audioPlayer.stop(); // Stop audio player

      String? videoId = YoutubePlayer.convertUrlToId(url);
      if (videoId != null) {
        if (_youtubeController != null) {
          _youtubeController!.load(videoId);
        } else {
          _youtubeController = YoutubePlayerController(
            initialVideoId: videoId,
            flags: const YoutubePlayerFlags(
              autoPlay: true,
              hideControls: true,
              enableCaption: false,
            ),
          );
        }
      }
    } else {
      // --- AUDIO MODE (JustAudio) ---
      if (_youtubeController != null) {
        _youtubeController!.pause(); // Pause YT
      }

      try {
        await _audioPlayer.stop(); // Reset state

        // FIX: Proper URI parsing for local files vs network
        Uri uri;
        if (url.startsWith('http')) {
          uri = Uri.parse(url);
        } else {
          // It's a local file path
          uri = Uri.file(url);
        }

        // Configure Source with Metadata (Notification Center)
        final source = AudioSource.uri(
          uri,
          tag: MediaItem(
            id: _currentLesson.id,
            album: "LinguaFlow",
            title: _currentLesson.title,
            artist: _currentLesson.language,
            artUri: _currentLesson.imageUrl != null
                ? Uri.parse(_currentLesson.imageUrl!)
                : null,
          ),
        );

        await _audioPlayer.setAudioSource(source);
        _audioPlayer.play();
      } catch (e) {
        debugPrint("Error loading audio: $e");
        // Fallback or alert user
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Error playing audio: $e")));
        }
      }
    }

    // Start Unified Sync Timer
    _startSyncTimer();
  }

  void _disposeMediaControllers() {
    _syncTimer?.cancel();
    _audioPlayer.stop();
  }

  @override
  void dispose() {
    _stopListeningTracker();
    if (_secondsListenedInSession > 10) {
      final minutes = (_secondsListenedInSession / 60).ceil();
      context.read<AuthBloc>().add(AuthUpdateListeningTime(minutes));
    }

    WidgetsBinding.instance.removeObserver(this);
    _syncTimer?.cancel();
    _youtubeController?.dispose();
    _audioPlayer.dispose();
    _flutterTts.stop();
    _listScrollController.dispose();
    super.dispose();
  }

  // --- SYNC ENGINE (Unified) ---

  void _startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => _checkSync(),
    );
  }

  void _checkSync() {
    if (_isSeeking || _isChangingTrack) return;

    bool playing = false;
    double currentSec = 0.0;
    double totalSec = 0.0;

    // Read from Active Player
    if (_isYoutube && _youtubeController != null) {
      playing = _youtubeController!.value.isPlaying;
      currentSec = _youtubeController!.value.position.inMilliseconds / 1000.0;
      totalSec = _youtubeController!.metadata.duration.inSeconds.toDouble();
    } else {
      // JustAudio
      playing = _audioPlayer.playing;
      currentSec = _audioPlayer.position.inMilliseconds / 1000.0;
      totalSec = (_audioPlayer.duration?.inSeconds ?? 0).toDouble();

      // FIX: Ensure UI knows if player finished
      if (_audioPlayer.processingState == ProcessingState.completed) {
        playing = false;
      }
    }

    // Update State
    if (mounted) {
      setState(() {
        if (playing != _isPlaying) _isPlaying = playing;
        _currentPosition = Duration(milliseconds: (currentSec * 1000).toInt());
        _totalDuration = Duration(milliseconds: (totalSec * 1000).toInt());
      });
    }

    // Auto-Advance
    if (totalSec > 0 && currentSec >= totalSec - 1.0) {
      _playNext();
      return;
    }

    // Transcript Sync
    if (_activeTranscript.isNotEmpty) {
      int activeIndex = -1;
      for (int i = 0; i < _activeTranscript.length; i++) {
        if (currentSec >= _activeTranscript[i].start &&
            currentSec < _activeTranscript[i].end) {
          activeIndex = i;
          break;
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

  // --- PLAYBACK CONTROLS ---

  void _playNext() {
    if (_currentIndex < widget.playlist.length - 1) {
      context.read<AuthBloc>().add(AuthIncrementLessonsCompleted());
      setState(() => _currentIndex++);
      _loadCurrentLesson();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Playlist Completed!")));
      }
    }
  }

  void _playPrev() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _loadCurrentLesson();
    }
  }

  void _togglePlayback() {
    if (_isYoutube && _youtubeController != null) {
      if (_isPlaying) {
        _youtubeController!.pause();
      } else {
        _youtubeController!.play();
      }
    } else {
      // FIX: Handle Replay if finished
      if (_audioPlayer.processingState == ProcessingState.completed) {
        _audioPlayer.seek(Duration.zero);
        _audioPlayer.play();
      } else {
        if (_isPlaying) {
          _audioPlayer.pause();
        } else {
          _audioPlayer.play();
        }
      }
    }
  }

  void _onSeek(double value) {
    final newPos = Duration(seconds: value.toInt());
    if (_isYoutube && _youtubeController != null) {
      _youtubeController!.seekTo(newPos);
    } else {
      _audioPlayer.seek(newPos);
    }
  }

  void _seekRelative(int seconds) {
    final newPos = _currentPosition + Duration(seconds: seconds);
    final clamped = Duration(
      seconds: newPos.inSeconds.clamp(0, _totalDuration.inSeconds),
    );

    if (_isYoutube && _youtubeController != null) {
      _youtubeController!.seekTo(clamped);
    } else {
      _audioPlayer.seek(clamped);
    }
  }

  // --- TRACKING & HELPERS ---

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

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return "${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}";
  }

  // --- UI CONSTRUCTION ---

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
      body: SafeArea(
        top: false,
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                // 1. MEDIA AREA
                Container(
                  height: _isYoutube ? 220 : 0.1, // Hide if not YT
                  width: double.infinity,
                  color: Colors.black,
                  child: _isYoutube && _youtubeController != null
                      ? YoutubePlayer(controller: _youtubeController!)
                      : null,
                ),

                // 2. CONTENT AREA
                Expanded(
                  child: SafeArea(
                    top: false,
                    child: Column(
                      children: [
                        // A. AUDIO THUMBNAIL (Only if not youtube)
                        if (!_isYoutube)
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
                                  image: _currentLesson.imageUrl != null
                                      ? NetworkImage(_currentLesson.imageUrl!)
                                      : const AssetImage(
                                              'assets/images/placeholder_audio.png',
                                            )
                                            as ImageProvider,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),

                        // B. TITLE INFO
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
                          child: _smartChunks.isEmpty
                              ? const Center(
                                  child: Text("No transcript available"),
                                )
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
                                      vocabulary: const {},
                                      language: _currentLesson.language,
                                      onWordTap: (w, c, p) =>
                                          _showDictionary(w, c),
                                      onPhraseSelected: (p, pos, c) =>
                                          _showDictionary(
                                            p,
                                            ReaderUtils.generateCleanId(p),
                                          ),
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

  Widget _buildPlayerControls() {
    final textColor = Theme.of(context).textTheme.bodyMedium?.color;
    const mainColor = Colors.red;

    final double maxVal = _totalDuration.inSeconds.toDouble();
    double currentVal = _currentPosition.inSeconds.toDouble();
    if (currentVal > maxVal) currentVal = maxVal;
    if (currentVal < 0) currentVal = 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // SLIDER
          Row(
            children: [
              Text(
                _formatDuration(_currentPosition),
                style: TextStyle(fontSize: 12, color: textColor),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4.0,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6.0,
                    ),
                    activeTrackColor: mainColor,
                    inactiveTrackColor: mainColor.withValues(alpha: 0.2),
                    thumbColor: mainColor,
                    overlayColor: mainColor.withValues(alpha: 0.2),
                  ),
                  child: Slider(
                    value: currentVal,
                    min: 0,
                    max: maxVal > 0 ? maxVal : 1.0,
                    onChanged: (value) {
                      setState(() {
                        _currentPosition = Duration(seconds: value.toInt());
                      });
                    },
                    onChangeStart: (_) => setState(() => _isSeeking = true),
                    onChangeEnd: (value) {
                      _isSeeking = false;
                      _onSeek(value);
                    },
                  ),
                ),
              ),
              Text(
                _formatDuration(_totalDuration),
                style: TextStyle(fontSize: 12, color: textColor),
              ),
            ],
          ),

          const SizedBox(height: 5),

          // BUTTONS
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.skip_previous, size: 32),
                onPressed: _currentIndex > 0 ? _playPrev : null,
                color: _currentIndex > 0 ? null : Colors.grey,
              ),
              IconButton(
                icon: const Icon(Icons.replay_10),
                onPressed: () => _seekRelative(-10),
              ),
              FloatingActionButton(
                backgroundColor: mainColor,
                onPressed: _togglePlayback,
                child: Icon(
                  _isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.forward_10),
                onPressed: () => _seekRelative(10),
              ),
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
        ],
      ),
    );
  }

  // --- DICTIONARY & UI HELPERS ---

  void _showDictionary(String text, String cleanId) {
    if (_isPlaying) _togglePlayback();
    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
    final svc = context.read<TranslationService>();

    setState(() {
      _showCard = true;
      _selectedText = text;
      _selectedCleanId = cleanId;
      _cardTranslationFuture = svc
          .translate(text, user.nativeLanguage, _currentLesson.language)
          .then((v) => v ?? "");
    });
  }

  Widget _buildDictionarySheet() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 250,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
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
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _showCard = false),
                ),
              ],
            ),
            const Divider(),
            FutureBuilder<String>(
              future: _cardTranslationFuture,
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting)
                  return const CircularProgressIndicator();
                return Text(
                  snap.data ?? "No translation",
                  style: TextStyle(
                    fontSize: 18,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                );
              },
            ),
          ],
        ),
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
                    return ListTile(
                      selected: index == _currentIndex,
                      leading: Image.network(
                        item.imageUrl ?? '',
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.audio_file),
                      ),
                      title: Text(item.title, maxLines: 1),
                      subtitle: Text(item.language),
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
}
