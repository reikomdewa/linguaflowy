import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/models/lesson_content.dart';
import 'package:linguaflow/screens/story_mode/widgets/loading_view.dart';
import 'package:linguaflow/services/lesson_generator_service.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class ActiveLessonScreen extends StatefulWidget {
  final LessonModel lesson;
  final int initialStep;

  const ActiveLessonScreen({
    super.key,
    required this.lesson,
    this.initialStep = 0,
  });

  @override
  State<ActiveLessonScreen> createState() => _ActiveLessonScreenState();
}

class _ActiveLessonScreenState extends State<ActiveLessonScreen> {
  final LessonGeneratorService _aiService = LessonGeneratorService();
  final FlutterTts _flutterTts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();

  LessonAIContent? _aiContent;
  bool _isLoading = true;

  // Steps Control
  int _currentStep = 0;
  late PageController _pageController;

  // Video Controller
  late YoutubePlayerController _ytController;

  // Vocabulary Logic
  int _vocabStepIndex = 0;

  // Grammar Logic
  int _grammarStepIndex = 0; // Tracks which grammar card is showing

  // Pronunciation Logic
  int _pronunciationStepIndex = 0;
  bool _isSpeechAvailable = false;
  bool _isListeningToUser = false;
  String _lastWords = '';
  bool? _isPronunciationCorrect;
  int _attemptsCount = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialStep);
    _currentStep = widget.initialStep;

    _ytController = YoutubePlayerController(
      initialVideoId: "",
      flags: const YoutubePlayerFlags(autoPlay: false, mute: false),
    );

    _initTts();
    _initSpeech();
    _loadLessonPlan();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage(widget.lesson.language);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.4);

    await _flutterTts
        .setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
        ], IosTextToSpeechAudioMode.voicePrompt);
  }

  Future<void> _initSpeech() async {
    try {
      _isSpeechAvailable = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted) {
              setState(() => _isListeningToUser = false);
            }
          }
        },
        onError: (errorNotification) {
          debugPrint('Speech Error: $errorNotification');
          if (mounted) {
            setState(() => _isListeningToUser = false);
          }
        },
      );
    } catch (e) {
      debugPrint("Speech init failed: $e");
      _isSpeechAvailable = false;
    }
  }

  Future<void> _speak(String text) async {
    await _flutterTts.stop();
    if (text.isNotEmpty) {
      await _flutterTts.speak(text);
    }
  }

  Future<void> _loadLessonPlan() async {
    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;

    final content = await _aiService.generateLessonPlan(
      transcriptText: widget.lesson.content,
      targetLang: widget.lesson.language,
      nativeLang: user.nativeLanguage,
    );

    if (widget.lesson.videoUrl != null) {
      final videoId =
          YoutubePlayer.convertUrlToId(widget.lesson.videoUrl!) ?? "";

      _ytController.dispose();
      _ytController = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(autoPlay: false, mute: false),
      );
      _ytController.addListener(_videoListener);
    }

    if (mounted) {
      setState(() {
        _aiContent = content;
        _isLoading = false;
      });
    }
  }

  void _videoListener() {
    if (_currentStep == 2 && mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _speech.stop();
    _ytController.removeListener(_videoListener);
    _ytController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _finishLesson() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const LoadingView(
        title: "Building Lesson...",
        tip: "Getting the vocabulary and grammar ready for you.",
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildProgressBar(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) {
                  setState(() => _currentStep = i);
                  if (i == 1 &&
                      _aiContent != null &&
                      _aiContent!.vocabulary.isNotEmpty) {
                    _speak(_aiContent!.vocabulary[0].word);
                  }
                },
                children: [
                  _buildStep1Vocabulary(),
                  _buildStep2Pronunciation(),
                  _buildStep3Video(),
                  _buildStep4Grammar(),
                  _buildStep5Chat(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    double progress = 0.0;
    if (_aiContent != null) {
      switch (_currentStep) {
        case 0: // Vocabulary
          if (_aiContent!.vocabulary.isNotEmpty) {
            progress = (_vocabStepIndex + 1) / _aiContent!.vocabulary.length;
          }
          break;
        case 1: // Pronunciation
          if (_aiContent!.vocabulary.isNotEmpty) {
            int totalSubSteps = _aiContent!.vocabulary.length * 2;
            progress = (_pronunciationStepIndex + 1) / totalSubSteps;
          }
          break;
        case 2: // Video
          if (_ytController.value.metaData.duration.inSeconds > 0) {
            progress =
                _ytController.value.position.inSeconds /
                _ytController.value.metaData.duration.inSeconds;
          }
          break;
        case 3: // Grammar
          if (_aiContent!.grammar.isNotEmpty) {
            progress = (_grammarStepIndex + 1) / _aiContent!.grammar.length;
          }
          break;
        case 4: // Chat
          progress = 1.0;
          break;
        default:
          progress = 0.0;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: Colors.grey[300],
                valueColor: const AlwaysStoppedAnimation(Colors.blue),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- STEP 1: VOCABULARY ---
  Widget _buildStep1Vocabulary() {
    final vocabList = _aiContent!.vocabulary;

    if (vocabList.isEmpty) {
      return Center(
        child: ElevatedButton(
          onPressed: _finishLesson,
          child: const Text("Finish Vocabulary"),
        ),
      );
    }

    final currentWord = vocabList[_vocabStepIndex];
    final isLastWord = _vocabStepIndex == vocabList.length - 1;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Text(
            "New Word (${_vocabStepIndex + 1}/${vocabList.length})",
            style: const TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),

          Expanded(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  margin: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.grey.shade200,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () => _speak(currentWord.word),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.volume_up_rounded,
                            color: Colors.blue,
                            size: 36,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        currentWord.word,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        currentWord.translation,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.grey[500],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Divider(),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () => _speak(currentWord.contextSentence),
                            child: Icon(
                              Icons.volume_up_rounded,
                              size: 20,
                              color: Colors.blue.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Example",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[400],
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        currentWord.contextSentence,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          height: 1.4,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        currentWord.contextTranslation,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[500],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 20.0, top: 10.0),
            child: ElevatedButton(
              onPressed: () {
                if (isLastWord) {
                  _finishLesson();
                } else {
                  setState(() => _vocabStepIndex++);
                }
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(60),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                elevation: 4,
              ),
              child: Text(
                isLastWord ? "Finish Vocabulary" : "Continue",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- STEP 2: PRONUNCIATION ---
  Widget _buildStep2Pronunciation() {
    final vocabList = _aiContent?.vocabulary ?? [];
    if (vocabList.isEmpty) return const SizedBox();

    final wordIndex = _pronunciationStepIndex ~/ 2;
    final isListeningPhase = _pronunciationStepIndex % 2 == 0;
    final currentWord = vocabList[wordIndex];
    final isLastSubStep = _pronunciationStepIndex == (vocabList.length * 2) - 1;

    final bool canProceed =
        isListeningPhase ||
        (_isPronunciationCorrect == true) ||
        (_attemptsCount >= 3);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Text(
            isListeningPhase ? "Listen Carefully" : "Your Turn",
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),

          Expanded(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isListeningPhase) ...[
                      GestureDetector(
                        onTap: () => _speak(currentWord.word),
                        child: Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.volume_up_rounded,
                            size: 64,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        currentWord.word,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        currentWord.translation,
                        style: TextStyle(fontSize: 20, color: Colors.grey[600]),
                      ),
                    ] else ...[
                      Text(
                        "Say: \"${currentWord.word}\"",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "(${currentWord.translation})",
                        style: TextStyle(fontSize: 18, color: Colors.grey[400]),
                      ),
                      const SizedBox(height: 40),

                      if (_lastWords.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            children: [
                              Text(
                                "I heard:",
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                _lastWords,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),

                      if (_isPronunciationCorrect != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 24),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _isPronunciationCorrect!
                                ? Colors.green.withValues(alpha: 0.1)
                                : Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isPronunciationCorrect!
                                    ? Icons.check_circle
                                    : Icons.error,
                                color: _isPronunciationCorrect!
                                    ? Colors.green
                                    : Colors.red,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _isPronunciationCorrect!
                                    ? "Perfect!"
                                    : "Try Again",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _isPronunciationCorrect!
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (_attemptsCount >= 3)
                        Container(
                          margin: const EdgeInsets.only(bottom: 24),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.skip_next, color: Colors.orange),
                              SizedBox(width: 8),
                              Text(
                                "Let's skip this one!",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                ),
                              ),
                            ],
                          ),
                        ),

                      GestureDetector(
                        onTap: () {
                          if (_isPronunciationCorrect == true ||
                              _attemptsCount >= 3) {
                            return;
                          }
                          _listenToUser(currentWord.word);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color:
                                (_isPronunciationCorrect == true ||
                                    _attemptsCount >= 3)
                                ? Colors.grey.shade200
                                : (_isListeningToUser
                                      ? Colors.red.withValues(alpha: 0.1)
                                      : Colors.blue.withValues(alpha: 0.1)),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color:
                                  (_isPronunciationCorrect == true ||
                                      _attemptsCount >= 3)
                                  ? Colors.grey
                                  : (_isListeningToUser
                                        ? Colors.red
                                        : Colors.blue),
                              width: 3,
                            ),
                          ),
                          child: Icon(
                            _isListeningToUser ? Icons.graphic_eq : Icons.mic,
                            size: 64,
                            color:
                                (_isPronunciationCorrect == true ||
                                    _attemptsCount >= 3)
                                ? Colors.grey
                                : (_isListeningToUser
                                      ? Colors.red
                                      : Colors.blue),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _isListeningToUser ? "Listening..." : "Tap to record",
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.only(bottom: 20, top: 10),
            child: ElevatedButton(
              onPressed: canProceed
                  ? () {
                      if (isListeningPhase) {
                        setState(() {
                          _pronunciationStepIndex++;
                          _isPronunciationCorrect = null;
                          _lastWords = '';
                          _attemptsCount = 0;
                        });
                      } else {
                        if (isLastSubStep) {
                          _finishLesson();
                        } else {
                          setState(() {
                            _pronunciationStepIndex++;
                            _lastWords = '';
                            _isPronunciationCorrect = null;
                            _attemptsCount = 0;
                          });

                          final nextWordIndex = _pronunciationStepIndex ~/ 2;
                          if (nextWordIndex < vocabList.length) {
                            _speak(vocabList[nextWordIndex].word);
                          }
                        }
                      }
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(60),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                isListeningPhase
                    ? "I'm Ready"
                    : (_attemptsCount >= 3
                          ? "Skip Word"
                          : (isLastSubStep
                                ? "Finish Pronunciation"
                                : "Next Word")),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- SPEECH RECOGNITION ---
  void _listenToUser(String targetWord) async {
    if (!_isListeningToUser) {
      bool available = _isSpeechAvailable;
      if (!available) {
        available = await _speech.initialize();
      }

      if (available) {
        var systemLocales = await _speech.locales();
        var targetCode = widget.lesson.language.toLowerCase().split('-')[0];

        stt.LocaleName? selectedLocale;
        try {
          selectedLocale = systemLocales.firstWhere(
            (l) =>
                l.localeId.toLowerCase() ==
                widget.lesson.language.toLowerCase(),
          );
        } catch (e) {
          try {
            selectedLocale = systemLocales.firstWhere(
              (l) => l.localeId.toLowerCase().startsWith(targetCode),
            );
          } catch (e) {
            selectedLocale = null;
          }
        }

        if (selectedLocale == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  "Your device doesn't support speech recognition for ${widget.lesson.language}. Please install the language pack in your Settings.",
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        setState(() {
          _isListeningToUser = true;
          _lastWords = '';
          _isPronunciationCorrect = null;
        });

        _speech.listen(
          onResult: (val) {
            setState(() {
              _lastWords = val.recognizedWords;
              if (val.finalResult) {
                _checkPronunciation(targetWord);
                _isListeningToUser = false;
              }
            });
          },
          localeId: selectedLocale.localeId,
          listenFor: const Duration(seconds: 10),
          pauseFor: const Duration(seconds: 2),
          listenOptions: stt.SpeechListenOptions(
            cancelOnError: true,
            partialResults: true,
          ),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Speech recognition permission denied or not available.",
              ),
            ),
          );
        }
      }
    } else {
      setState(() => _isListeningToUser = false);
      _speech.stop();
      _checkPronunciation(targetWord);
    }
  }

  void _checkPronunciation(String targetWord) {
    if (_lastWords.isEmpty) return;

    final cleanTarget = targetWord.toLowerCase().trim().replaceAll(
      RegExp(r'[^\w\s]+'),
      '',
    );
    final cleanInput = _lastWords.toLowerCase().trim().replaceAll(
      RegExp(r'[^\w\s]+'),
      '',
    );

    final isMatch =
        cleanInput.contains(cleanTarget) || cleanTarget.contains(cleanInput);

    setState(() {
      _isPronunciationCorrect = isMatch;
      if (!isMatch) {
        _attemptsCount++;
      }
    });
  }

  // --- STEP 3: VIDEO ---
  Widget _buildStep3Video() {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            "Watch & Listen",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
        if (_ytController.initialVideoId.isNotEmpty)
          YoutubePlayer(
            controller: _ytController,
            showVideoProgressIndicator: true,
            bottomActions: [
              CurrentPosition(),
              ProgressBar(isExpanded: true),
              RemainingDuration(),
            ],
          )
        else
          Container(
            height: 200,
            color: Colors.black,
            alignment: Alignment.center,
            child: const Text(
              "Video not available",
              style: TextStyle(color: Colors.white),
            ),
          ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Text(
              widget.lesson.content,
              style: const TextStyle(fontSize: 18, height: 1.6),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
          child: ElevatedButton(
            onPressed: () {
              _ytController.pause();
              _finishLesson();
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(60),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text("Finish Video", style: TextStyle(fontSize: 18)),
          ),
        ),
      ],
    );
  }

  // --- STEP 4: GRAMMAR (UPDATED) ---
  Widget _buildStep4Grammar() {
    final grammarList = _aiContent!.grammar;
    final bool isLastGrammar = _grammarStepIndex == grammarList.length - 1;

    // Safety check
    if (grammarList.isEmpty) {
      return Center(
        child: ElevatedButton(
          onPressed: _finishLesson,
          child: const Text("Finish Grammar"),
        ),
      );
    }

    final currentGrammar = grammarList[_grammarStepIndex];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          // Show progress X/Y
          Text(
            "Grammar Focus (${_grammarStepIndex + 1}/${grammarList.length})",
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Card(
                  color: Colors.amber.shade50,
                  margin: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.lightbulb,
                                color: Colors.amber,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                currentGrammar.title,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 40),
                        Text(
                          currentGrammar.explanation,
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.black87,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "EXAMPLE",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[400],
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                currentGrammar.example,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Navigation Buttons for Grammar
          Padding(
            padding: const EdgeInsets.only(bottom: 20, top: 10),
            child: ElevatedButton(
              onPressed: () {
                if (isLastGrammar) {
                  _finishLesson(); // Done with grammar module
                } else {
                  setState(() {
                    _grammarStepIndex++;
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(60),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                isLastGrammar ? "Finish Grammar" : "Next Rule",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- STEP 5: CHAT ---
  Widget _buildStep5Chat() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              size: 60,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            "Practice Conversation",
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            "Use the words you just learned to have a short conversation with AI about the video topic.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 18, height: 1.4),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(Icons.chat),
            label: const Text("Start Chat"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(60),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "Finish Lesson",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
