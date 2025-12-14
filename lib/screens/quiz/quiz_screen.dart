import 'dart:async';
import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/quiz/quiz_bloc.dart';
import 'package:linguaflow/services/quiz_service.dart';
import 'package:linguaflow/services/translation_service.dart';
import 'package:linguaflow/utils/language_helper.dart';

// --- IMPORT WIDGETS ---
import 'widgets/quiz_word_chip.dart';
import 'widgets/quiz_bottom_bar.dart';
import 'widgets/quiz_loading_view.dart';
import 'widgets/quiz_dialogs.dart';

class QuizScreen extends StatefulWidget {
  final List<dynamic>? initialQuestions;
  final String? levelId;

  const QuizScreen({super.key, this.initialQuestions, this.levelId});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final FlutterTts _tts = FlutterTts();

  // --- VIDEO STATE ---
  YoutubePlayerController? _videoController;
  Timer? _videoSegmentTimer;
  bool _isVideoReady = false;
  String? _currentLoadedVideoId;
  bool _isManuallyPlaying = false;

  // --- QUIZ STATE ---
  String _targetLangCode = 'en';
  String _targetLangName = 'English';
  String _targetFlag = '🇬🇧';
  Timer? _cooldownTimer;
  final int _secondsRemaining = 0;
  int _retryCount = 0;
  bool _hasLoaded = false;

  @override
  void initState() {
    super.initState();
    _initializeAppSequence();
    if (widget.levelId != null && widget.levelId!.startsWith('yt_')) {
      _loadVideoById(widget.levelId!.replaceFirst('yt_', ''));
    }
  }

  // --- VIDEO LOGIC ---

  void _loadVideoById(String videoId) {
    if (_currentLoadedVideoId == videoId) return;

    _videoController?.dispose();
    _currentLoadedVideoId = videoId;

    _videoController =
        YoutubePlayerController(
          initialVideoId: videoId,
          flags: const YoutubePlayerFlags(
            autoPlay: false,
            mute: false,
            disableDragSeek: false,
            enableCaption: false,
            controlsVisibleAtStart: true,
            hideControls: false,
            forceHD: false,
          ),
        )..addListener(() {
          if (mounted) {
            setState(() {
              _isVideoReady = _videoController!.value.isReady;
            });
          }
        });
    setState(() {});
  }

  /// Plays the sentence with PADDING on both sides
  void _playVideoSegment(double startSeconds, double endSeconds) {
    if (_videoController == null || !_isVideoReady) return;

    if (_isManuallyPlaying) return;

    _videoSegmentTimer?.cancel();

    // 1. SUBTRACT FROM START (Start 0.5s earlier)
    // We clamp to 0.0 to prevent negative time errors
    double paddedStart = startSeconds - 1.5;
    if (paddedStart < 0.0) paddedStart = 0.0;

    // 2. SEEK to the new earlier start time
    _videoController!.seekTo(
      Duration(milliseconds: (paddedStart * 1000).toInt()),
    );
    _videoController!.play();

    // 3. ADD TO END (Calculate duration based on original end + 1.5s buffer)
    // Duration = (Original End - New Start) + 1.5 seconds safety
    double playDuration = (endSeconds - paddedStart) + 2;

    final durationMs = (playDuration * 1000).toInt();

    // 4. Set Timer
    _videoSegmentTimer = Timer(Duration(milliseconds: durationMs), () {
      if (mounted && !_isManuallyPlaying) _videoController!.pause();
    });
  }

  /// Plays 30 seconds of context starting slightly before the sentence
  void _playContext(double startSeconds) {
    if (_videoController == null || !_isVideoReady) return;

    setState(() => _isManuallyPlaying = true);
    _videoSegmentTimer?.cancel();

    // Start 0.5s earlier for context too
    double paddedStart = startSeconds - 0.5;
    if (paddedStart < 0.0) paddedStart = 0.0;

    _videoController!.seekTo(
      Duration(milliseconds: (paddedStart * 1000).toInt()),
    );
    _videoController!.play();

    _videoSegmentTimer = Timer(const Duration(seconds: 30), () {
      if (mounted) {
        _videoController!.pause();
        setState(() => _isManuallyPlaying = false);
      }
    });
  }

  // --- APP & TTS SETUP ---
  Future<void> _initializeAppSequence() async {
    if (Platform.isAndroid) await Future.delayed(const Duration(seconds: 1));
    try {
      await _tts.awaitSpeakCompletion(true);
      await _tts.setVolume(1.0);
    } catch (_) {}
    if (!mounted) return;
    if (context.read<QuizBloc>().state.status == QuizStatus.initial) {
      _loadQuiz();
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _videoSegmentTimer?.cancel();
    _videoController?.dispose();
    _tts.stop();
    super.dispose();
  }

  void _loadQuiz() async {
    if (_hasLoaded) return;
    _hasLoaded = true;

    final authState = context.read<AuthBloc>().state;
    String targetLang = 'es';
    String nativeLang = 'en';
    String userId = '';
    bool isPremium = false;

    if (authState is AuthAuthenticated) {
      targetLang = LanguageHelper.getLangCode(authState.user.currentLanguage);
      nativeLang = LanguageHelper.getLangCode(authState.user.nativeLanguage);
      userId = authState.user.id;
      isPremium = authState.user.isPremium;
      if (mounted) {
        setState(() {
          _targetLangCode = targetLang;
          _targetLangName = LanguageHelper.getLanguageName(targetLang);
          _targetFlag = LanguageHelper.getFlagEmoji(targetLang);
        });
      }
    }
    try {
      await _tts.setLanguage(_targetLangCode);
    } catch (_) {}
    if (!mounted) return;

    if (widget.initialQuestions != null &&
        widget.initialQuestions!.isNotEmpty) {
      context.read<QuizBloc>().add(
        QuizStartWithQuestions(
          questions: widget.initialQuestions!,
          userId: userId,
          isPremium: isPremium,
        ),
      );
    } else {
      context.read<QuizBloc>().add(
        QuizLoadRequested(
          promptType: QuizPromptType.dailyPractice,
          userId: userId,
          targetLanguage: targetLang,
          nativeLanguage: nativeLang,
          isPremium: isPremium,
        ),
      );
    }
  }

  Future<void> _saveProgress() async {
    if (widget.levelId == null) return;
    try {
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated) {
        final userId = authState.user.id;
        await FirebaseFirestore.instance.collection('users').doc(userId).update(
          {
            'completedLevels': FieldValue.arrayUnion([widget.levelId]),
          },
        );
      }
    } catch (_) {}
  }

  void _speakOrPlayContext(String text, {double? start, double? end}) async {
    if (_videoController != null &&
        _isVideoReady &&
        start != null &&
        end != null) {
      setState(() => _isManuallyPlaying = false);
      _playVideoSegment(start, end);
      return;
    }
    try {
      await _tts.setLanguage(_targetLangCode);
      await _tts.speak(text);
    } catch (_) {}
  }

  void _showWordHint(String cleanWord, String originalWord) {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    final translationFuture = context.read<TranslationService>().translate(
      originalWord,
      LanguageHelper.getLangCode(authState.user.nativeLanguage),
      LanguageHelper.getLangCode(authState.user.currentLanguage),
    );

    showDialog(
      context: context,
      barrierColor: Colors.black12,
      builder: (context) => QuizHintDialog(
        originalWord: originalWord,
        translationFuture: translationFuture.then((value) => value ?? ''),
        onSpeak: () => _speakOrPlayContext(originalWord),
      ),
    );
  }

  void _retryQuizLoad() {
    setState(() {
      _retryCount++;
      _hasLoaded = false;
    });
    _initializeAppSequence();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: BlocBuilder<QuizBloc, QuizState>(
          builder: (context, state) {
            if (state.status == QuizStatus.loading ||
                state.status == QuizStatus.error) {
              return const SizedBox();
            }
            return ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: state.progress,
                minHeight: 6,
                backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation(Colors.blueAccent),
              ),
            );
          },
        ),
        actions: [
          BlocBuilder<QuizBloc, QuizState>(
            builder: (context, state) {
              if (state.status == QuizStatus.loading ||
                  state.status == QuizStatus.error) {
                return const SizedBox();
              }
              return Padding(
                padding: const EdgeInsets.only(right: 20.0),
                child: Row(
                  children: [
                    const Icon(
                      Icons.favorite,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      state.isPremium ? "∞" : "${state.hearts}",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: BlocConsumer<QuizBloc, QuizState>(
        listener: (context, state) {
          if (state.status == QuizStatus.completed) {
            _saveProgress();
            QuizDialogs.showCompletion(context, isDark);
          }
          if (state.hearts <= 0 &&
              !state.isPremium &&
              state.status != QuizStatus.loading &&
              state.status != QuizStatus.error) {
            QuizDialogs.showGameOver(context, isDark);
          }

          if (state.status != QuizStatus.loading &&
              state.currentQuestion != null) {
            final q = state.currentQuestion!;

            if (q.videoUrl != null && q.videoUrl!.isNotEmpty) {
              String? vidId = YoutubePlayer.convertUrlToId(q.videoUrl!);
              if (vidId != null && vidId != _currentLoadedVideoId) {
                _loadVideoById(vidId);
              }
            }
            setState(() => _isManuallyPlaying = false);

            if (q.videoStart != null && q.videoEnd != null) {
              Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted) _playVideoSegment(q.videoStart!, q.videoEnd!);
              });
            }
          }
        },
        builder: (context, state) {
          if (state.status == QuizStatus.loading) {
            return QuizLoadingView(
              languageName: _targetLangName,
              flag: _targetFlag,
            );
          }

          if (state.status == QuizStatus.error) {
            return _buildErrorView(state.errorMessage ?? "");
          }

          final question = state.currentQuestion;
          if (question == null) return const SizedBox();

          final isTargetQ = question.type == 'target_to_native';
          final areOptionsTarget = question.type == 'native_to_target';
          final hasVideoContext =
              _videoController != null && question.videoStart != null;

          return Column(
            children: [
              // 1. VIDEO PLAYER AREA
              if (_videoController != null)
                Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(color: Colors.black26, blurRadius: 8),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // LAYER 1: The Player
                            YoutubePlayer(
                              controller: _videoController!,
                              showVideoProgressIndicator: true,
                              progressIndicatorColor: Colors.blueAccent,
                              bottomActions: [
                                // "The Play Button on the Controls"
                                if (hasVideoContext)
                                  IconButton(
                                    icon: Icon(
                                      _videoController!.value.isPlaying
                                          ? Icons.pause
                                          : Icons.play_arrow,
                                      color: Colors.white,
                                    ),
                                    onPressed: () {
                                      if (_videoController!.value.isPlaying) {
                                        _videoController!.pause();
                                      } else {
                                        // Jump to padded start
                                        _playVideoSegment(
                                          question.videoStart!,
                                          question.videoEnd!,
                                        );
                                      }
                                    },
                                  ),
                                CurrentPosition(),
                                ProgressBar(isExpanded: true),
                                RemainingDuration(),
                              ],
                            ),

                            // LAYER 2: "Play Button in the Middle"
                            if (!_videoController!.value.isPlaying &&
                                hasVideoContext)
                              GestureDetector(
                                onTap: () => _playVideoSegment(
                                  question.videoStart!,
                                  question.videoEnd!,
                                ),
                                child: Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: Colors.black45,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.play_arrow,
                                    color: Colors.white,
                                    size: 40,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    // "Watch 30s Context" Button
                    if (hasVideoContext)
                      GestureDetector(
                        onTap: () => _playContext(question.videoStart!),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 16,
                          ),
                          decoration: BoxDecoration(
                            color: _isManuallyPlaying
                                ? Colors.blueAccent
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.blueAccent),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isManuallyPlaying
                                    ? Icons.pause
                                    : Icons.play_arrow,
                                size: 16,
                                color: _isManuallyPlaying
                                    ? Colors.white
                                    : Colors.blueAccent,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _isManuallyPlaying
                                    ? "Playing Context..."
                                    : "Watch 30s Context",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _isManuallyPlaying
                                      ? Colors.white
                                      : Colors.blueAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                  ],
                ),

              // 2. SCROLLABLE QUIZ CONTENT
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        Text(
                          hasVideoContext
                              ? "What was said in the video?"
                              : "Translate this sentence",
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // SENTENCE ROW
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isTargetQ)
                              GestureDetector(
                                onTap: () => _speakOrPlayContext(
                                  question.targetSentence,
                                  start: question.videoStart,
                                  end: question.videoEnd,
                                ),
                                child: Container(
                                  margin: const EdgeInsets.only(right: 16),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.blueAccent.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    hasVideoContext
                                        ? Icons.replay_circle_filled
                                        : Icons.volume_up,
                                    color: Colors.blueAccent,
                                    size: 24,
                                  ),
                                ),
                              ),
                            Expanded(
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: question.targetSentence
                                    .split(' ')
                                    .map((word) {
                                      final cleanWord = word.replaceAll(
                                        RegExp(r'[^\w\s]'),
                                        '',
                                      );
                                      if (isTargetQ) {
                                        return GestureDetector(
                                          onTap: () =>
                                              _showWordHint(cleanWord, word),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              border: Border(
                                                bottom: BorderSide(
                                                  color: Colors.grey
                                                      .withOpacity(0.5),
                                                  width: 1.5,
                                                ),
                                              ),
                                            ),
                                            child: Text(
                                              word,
                                              style: TextStyle(
                                                fontSize: 22,
                                                height: 1.4,
                                                color: textColor,
                                              ),
                                            ),
                                          ),
                                        );
                                      } else {
                                        return Text(
                                          word,
                                          style: TextStyle(
                                            fontSize: 22,
                                            height: 1.4,
                                            color: textColor,
                                          ),
                                        );
                                      }
                                    })
                                    .toList(),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // ANSWER AREA
                        Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(minHeight: 80),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: isDark ? Colors.white24 : Colors.black12,
                                width: 1,
                              ),
                            ),
                          ),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 12,
                            children: state.selectedWords.map((word) {
                              return QuizWordChip(
                                word: word,
                                isSelectedArea: true,
                                onTap: () => context.read<QuizBloc>().add(
                                  QuizOptionDeselected(word),
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // WORD BANK
                        Center(
                          child: Wrap(
                            spacing: 12,
                            runSpacing: 16,
                            alignment: WrapAlignment.center,
                            children: state.availableWords.map((word) {
                              return QuizWordChip(
                                word: word,
                                isSelectedArea: false,
                                shouldSpeak: areOptionsTarget,
                                onSpeak: (w) => _speakOrPlayContext(w),
                                onTap: () => context.read<QuizBloc>().add(
                                  QuizOptionSelected(word),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. BOTTOM BAR
              QuizBottomBar(
                state: state,
                onCheck: () => context.read<QuizBloc>().add(QuizCheckAnswer()),
                onNext: () => context.read<QuizBloc>().add(QuizNextQuestion()),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildErrorView(String msg) {
    return Center(child: Text(msg));
  }
}
