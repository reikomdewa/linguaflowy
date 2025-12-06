import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/models/lesson_content.dart';
import 'package:linguaflow/screens/story_mode/widgets/loading_view.dart';
import 'package:linguaflow/services/lesson_generator_service.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class ActiveLessonScreen extends StatefulWidget {
  final LessonModel lesson;
  final int initialStep;

  const ActiveLessonScreen({super.key, required this.lesson, this.initialStep = 0});

  @override
  State<ActiveLessonScreen> createState() => _ActiveLessonScreenState();
}

class _ActiveLessonScreenState extends State<ActiveLessonScreen> {
  final LessonGeneratorService _aiService = LessonGeneratorService();
  final FlutterTts _flutterTts = FlutterTts();
  
  LessonAIContent? _aiContent;
  bool _isLoading = true;
  
  // Steps Control
  int _currentStep = 0;
  late PageController _pageController;

  // Video Controller
  late YoutubePlayerController _ytController;

  // Vocabulary Logic
  int _vocabStepIndex = 0; 

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialStep);
    _currentStep = widget.initialStep;
    
    _initTts();
    _loadLessonPlan();
  }

  Future<void> _initTts() async {
    // Set language (e.g. 'es-ES' for Spanish)
    await _flutterTts.setLanguage(widget.lesson.language); 
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.4); // Slow down for clarity
    
    await _flutterTts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers
        ],
        IosTextToSpeechAudioMode.voicePrompt
    );
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
      final videoId = YoutubePlayer.convertUrlToId(widget.lesson.videoUrl!) ?? "";
      _ytController = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(autoPlay: false, mute: false),
      );
    }

    if (mounted) {
      setState(() {
        _aiContent = content;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _ytController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300), 
      curve: Curves.easeInOut
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const LoadingView(
        title: "Building Lesson...",
        tip: "Getting important vocabulary and grammar ready for you.",
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
                onPageChanged: (i) => setState(() => _currentStep = i),
                children: [
                  _buildStep1_Vocabulary(),
                  _buildStep2_Pronunciation(),
                  _buildStep3_Video(),
                  _buildStep4_Grammar(),
                  _buildStep5_Chat(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    double progress = (_currentStep) / 5;
    // Add micro-progress for vocabulary steps
    if (_currentStep == 0 && _aiContent != null && _aiContent!.vocabulary.isNotEmpty) {
      progress += (_vocabStepIndex / _aiContent!.vocabulary.length) * 0.2;
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
                value: progress + 0.05,
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
  Widget _buildStep1_Vocabulary() {
    final vocabList = _aiContent!.vocabulary;
    
    // Safety check if list is empty
    if (vocabList.isEmpty) {
      return Center(
        child: ElevatedButton(onPressed: _nextPage, child: const Text("Skip Vocabulary")),
      );
    }

    final currentWord = vocabList[_vocabStepIndex];
    final isLastWord = _vocabStepIndex == vocabList.length - 1;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Text(
            "New Word (${_vocabStepIndex + 1}/${vocabList.length})", 
            style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)
          ),
          
          const Spacer(),

          // --- CARD ---
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 10))
              ],
              border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Speaker
                GestureDetector(
                  onTap: () => _speak("${currentWord.word}... ${currentWord.contextSentence}"),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.volume_up_rounded, color: Colors.blue, size: 36),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Word
                Text(
                  currentWord.word,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 36, 
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  currentWord.translation,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, color: Colors.grey[500], fontStyle: FontStyle.italic),
                ),
                
                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 24),

                // Example
                Text(
                  "Example:",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[400], letterSpacing: 1),
                ),
                const SizedBox(height: 12),
                Text(
                  currentWord.contextSentence,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, height: 1.4, color: isDark ? Colors.white70 : Colors.black87),
                ),
                const SizedBox(height: 8),
                // --- NEW: SENTENCE TRANSLATION ---
                Text(
                  currentWord.contextTranslation, // Ensure this exists in your Model
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey[500], fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),

          const Spacer(),

          // --- BUTTON ---
          ElevatedButton(
            onPressed: () {
              if (isLastWord) {
                _nextPage(); // Just move to next section
              } else {
                setState(() => _vocabStepIndex++);
              }
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(60),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: Colors.blue, // Keep distinct color
              foregroundColor: Colors.white,
              elevation: 4,
            ),
            child: Text(
              "Continue", // Standard Busuu-like text
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // --- STEP 2: PRONUNCIATION ---
  Widget _buildStep2_Pronunciation() {
    // Just grab a word from the list to practice
    final word = _aiContent?.vocabulary.isNotEmpty == true 
        ? _aiContent!.vocabulary[0].word 
        : "Hola";
    
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("Speak the word", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 40),
          
          Text(word, style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: Colors.blue)),
          const SizedBox(height: 60),
          
          GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Listening... (Mock)")));
              Future.delayed(const Duration(seconds: 2), _nextPage);
            },
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.blue, width: 3),
              ),
              child: const Icon(Icons.mic, size: 64, color: Colors.blue),
            ),
          ),
          const SizedBox(height: 24),
          const Text("Tap to record", style: TextStyle(color: Colors.grey, fontSize: 16)),
          
          const Spacer(),
          TextButton(
            onPressed: _nextPage, 
            child: const Text("Skip for now", style: TextStyle(color: Colors.grey))
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // --- STEP 3: VIDEO ---
  Widget _buildStep3_Video() {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(24.0),
          child: Text("Watch & Listen", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
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
            child: const Text("Video not available", style: TextStyle(color: Colors.white)),
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
          padding: const EdgeInsets.all(24.0),
          child: ElevatedButton(
            onPressed: () {
              _ytController.pause();
              _nextPage();
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(60),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text("Continue to Grammar", style: TextStyle(fontSize: 18)),
          ),
        ),
      ],
    );
  }

  // --- STEP 4: GRAMMAR ---
  Widget _buildStep4_Grammar() {
    final grammar = _aiContent!.grammar;
    
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text("Grammar Focus", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          
          Card(
            color: Colors.amber.shade50,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.lightbulb, color: Colors.amber),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(grammar.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87))),
                    ],
                  ),
                  const Divider(height: 40),
                  Text(grammar.explanation, style: const TextStyle(fontSize: 18, color: Colors.black87, height: 1.4)),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("EXAMPLE", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[400], letterSpacing: 1)),
                        const SizedBox(height: 8),
                        Text(grammar.example, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[800])),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const Spacer(),
          ElevatedButton(
            onPressed: _nextPage,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(60),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text("Got it!", style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // --- STEP 5: CHAT ---
  Widget _buildStep5_Chat() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
            child: const Icon(Icons.chat_bubble_outline_rounded, size: 60, color: Colors.green),
          ),
          const SizedBox(height: 32),
          const Text("Practice Conversation", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          const Text(
            "Use the words you just learned to have a short conversation with AI about the video topic.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 18, height: 1.4),
          ),
          const SizedBox(height: 48),
          
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context); 
              // TODO: Push to ChatScreen
            },
            icon: const Icon(Icons.chat),
            label: const Text("Start Chat"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(60),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text("Finish Lesson", style: TextStyle(fontSize: 16, color: Colors.grey)),
          ),
        ],
      ),
    );
  }
}