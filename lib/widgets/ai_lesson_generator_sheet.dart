import 'dart:async'; // Required for Timer
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/blocs/lesson/lesson_bloc.dart';
import 'package:linguaflow/screens/story_mode/widgets/loading_view.dart';

class AILessonGeneratorSheet extends StatefulWidget {
  final String userId;
  final String targetLanguage;

  const AILessonGeneratorSheet({
    super.key,
    required this.userId,
    required this.targetLanguage,
  });

  @override
  State<AILessonGeneratorSheet> createState() => _AILessonGeneratorSheetState();
}

class _AILessonGeneratorSheetState extends State<AILessonGeneratorSheet> {
  final TextEditingController _promptController = TextEditingController();
  String _selectedLevel = 'A1';
  final List<String> _levels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];

  final List<String> _prompts = [
    "Avengers eating Shawarma",
    "Ordering coffee in Paris",
    "Job interview at Google",
    "Lost astronaut in space",
    "Detective interrogating a dragon",
    "Cooking a magical pizza",
    "First date in Tokyo",
    "Buying a train ticket",
    "Zombies in the supermarket",
    "A cat describing its day",
    "Explaining internet to a viking",
    "Negotiating with a merchant",
    "Superhero laundry day",
    "Time traveler lost in 2024",
    "Robot learning to love",
  ];

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  void _generateLesson() {
    if (_promptController.text.trim().isEmpty) return;

    FocusScope.of(context).unfocus();

    final lessonBloc = context.read<LessonBloc>();
    final topic = _promptController.text;
    final level = _selectedLevel;

    // 1. Fire the initial Generation Event
    lessonBloc.add(
      LessonGenerateRequested(
        userId: widget.userId,
        topic: topic,
        level: level,
        targetLanguage: widget.targetLanguage,
      ),
    );

    // 2. Close the Bottom Sheet
    Navigator.pop(context);

    // 3. Push the new Smart Wrapper instead of the dumb LoadingView
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: lessonBloc,
          child: _LessonGenerationScreen(
            userId: widget.userId,
            targetLanguage: widget.targetLanguage,
            topic: topic,
            level: level,
          ),
        ),
      ),
    ).then((_) {
      // 4. Reload list when returning (Success or User cancelled)
      lessonBloc.add(LessonLoadRequested(widget.userId, widget.targetLanguage));
    });
  }

  void _applyIdea(String text) {
    setState(() {
      _promptController.text = text;
      _promptController.selection = TextSelection.fromPosition(
        TextPosition(offset: text.length),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final keyboardHeight = mediaQuery.viewInsets.bottom;
    final topPadding = mediaQuery.padding.top;
    final isKeyboardOpen = keyboardHeight > 0;

    final backgroundColor = theme.scaffoldBackgroundColor;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.grey[100];
    final borderColor = isDark ? Colors.grey[800] : Colors.grey[300];
    final textColor = isDark ? Colors.white : Colors.black87;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      height: isKeyboardOpen ? screenHeight : screenHeight * 0.85,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(top: isKeyboardOpen ? topPadding : 0),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "AI Lesson Creator",
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Difficulty",
                    style: TextStyle(
                      color: textColor.withOpacity(0.7),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _levels.map((level) {
                        final isSelected = _selectedLevel == level;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(level),
                            selected: isSelected,
                            onSelected: (val) {
                              if (val) setState(() => _selectedLevel = level);
                            },
                            selectedColor: theme.primaryColor,
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : theme.textTheme.bodyLarge?.color,
                              fontWeight: FontWeight.bold,
                            ),
                            backgroundColor: cardColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: isSelected
                                    ? Colors.transparent
                                    : borderColor!,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 140,
                    child: GridView.builder(
                      scrollDirection: Axis.horizontal,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 0.3,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                      ),
                      itemCount: _prompts.length,
                      itemBuilder: (context, index) {
                        final text = _prompts[index];
                        return GestureDetector(
                          onTap: () => _applyIdea(text),
                          child: Container(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: borderColor!,
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              text,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: textColor.withOpacity(0.9),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "What kind of story do you want?",
                    style: TextStyle(
                      color: textColor.withOpacity(0.7),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _promptController,
                    maxLines: isKeyboardOpen ? 8 : 5,
                    style: theme.textTheme.bodyLarge,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText:
                          'e.g., A sci-fi story about a robot learning to paint...',
                      hintStyle: TextStyle(color: Colors.grey.withOpacity(0.5)),
                      filled: true,
                      fillColor: cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: isKeyboardOpen
                  ? keyboardHeight + 16
                  : mediaQuery.padding.bottom + 16,
            ),
            decoration: BoxDecoration(
              color: backgroundColor,
              border: Border(top: BorderSide(color: borderColor!)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _generateLesson,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.auto_awesome, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      "Generate Lesson",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// --------------------------------------------------------------------------
/// NEW WRAPPER SCREEN: Handles Loading, 429 Errors, Retries, and Success
/// --------------------------------------------------------------------------
class _LessonGenerationScreen extends StatefulWidget {
  final String userId;
  final String targetLanguage;
  final String topic;
  final String level;

  const _LessonGenerationScreen({
    required this.userId,
    required this.targetLanguage,
    required this.topic,
    required this.level,
  });

  @override
  State<_LessonGenerationScreen> createState() =>
      _LessonGenerationScreenState();
}



class _LessonGenerationScreenState extends State<_LessonGenerationScreen> {
  // Cooldown variables
  Timer? _cooldownTimer;
  int _secondsRemaining = 0;
  int _retryCount = 0;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() {
      _secondsRemaining = 60; // Standard Gemini/API free tier reset time
    });

    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_secondsRemaining > 0) {
            _secondsRemaining--;
          } else {
            _cooldownTimer?.cancel();
          }
        });
      }
    });
  }

  void _retryGeneration() {
    setState(() {
      _retryCount++;
    });

    // Fire the same event again
    context.read<LessonBloc>().add(
          LessonGenerateRequested(
            userId: widget.userId,
            topic: widget.topic,
            level: widget.level,
            targetLanguage: widget.targetLanguage,
          ),
        );
  }

  String _getFriendlyErrorMessage(String error) {
    if (_retryCount >= 1) {
      return "The AI is too busy right now. Please try again later.";
    }
    if (error.contains("429") || error.contains("Too Many Requests")) {
      return "Server is busy. Please wait a moment.";
    }
    if (error.contains("SocketException") || error.contains("Network")) {
      return "Check your internet connection.";
    }
    return "Failed to create story.";
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LessonBloc, LessonState>(
      listener: (context, state) {
        // 1. Success -> Close this screen
        // CHANGED: Check type 'is LessonGenerationSuccess'
        if (state is LessonGenerationSuccess) {
          Navigator.pop(context); 
        }

        // 2. Error -> Start Timer and Show SnackBar
        // CHANGED: Check type 'is LessonError'
        if (state is LessonError) {
          _startCooldown();
          final message = _getFriendlyErrorMessage(state.message);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      },
      builder: (context, state) {
        final bgColor = Theme.of(context).scaffoldBackgroundColor;

        // --- LOADING STATE ---
        // CHANGED: Check type 'is LessonLoading'
        if (state is LessonLoading) {
          return const LoadingView(
            tip: "Creating your unique story...",
            title: "Writing Story",
            subtitle: "This may take a few seconds",
          );
        }

        // --- ERROR STATE ---
        // CHANGED: Check type 'is LessonError'
        if (state is LessonError) {
          final bool isFinalFailure = _retryCount >= 2;
          // CHANGED: Access 'state.message' directly
          final errorMessage = _getFriendlyErrorMessage(state.message);

          return Scaffold(
            backgroundColor: bgColor,
            appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isFinalFailure ? Icons.block : Icons.access_time_filled,
                      size: 64,
                      color: isFinalFailure ? Colors.red : Colors.orange,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isFinalFailure ? "Limit Reached" : "Server Busy",
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isFinalFailure
                          ? "We cannot generate the story right now. Please try again tomorrow."
                          : errorMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                    const SizedBox(height: 30),

                    // RETRY BUTTON
                    if (!isFinalFailure)
                      ElevatedButton(
                        onPressed: _secondsRemaining > 0
                            ? null
                            : _retryGeneration,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 14),
                          backgroundColor: Colors.blueAccent,
                        ),
                        child: Text(
                          _secondsRemaining > 0
                              ? "Wait ${_secondsRemaining}s"
                              : "Retry Now",
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),

                    // BACK BUTTON
                    if (isFinalFailure)
                      ElevatedButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text("Go Back"),
                      ),
                  ],
                ),
              ),
            ),
          );
        }

        // Fallback for any other state
        return const SizedBox();
      },
    );
  }
}