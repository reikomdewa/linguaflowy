import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/blocs/lesson/lesson_bloc.dart';
// IMPORT THE NEW WRAPPER SCREEN HERE
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

    // 1. Unfocus keyboard
    FocusScope.of(context).unfocus();

    // 2. Capture the Bloc (Safety first)
    final lessonBloc = context.read<LessonBloc>();

    // 3. Fire the Generation Event
    lessonBloc.add(
      LessonGenerateRequested(
        userId: widget.userId,
        topic: _promptController.text,
        level: _selectedLevel,
        targetLanguage: widget.targetLanguage,
      ),
    );

    // 4. Close the Bottom Sheet
    Navigator.pop(context);

    // 5. Navigate to Wrapper AND Wait for return
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: lessonBloc, // Pass the existing bloc
          child: LoadingView(tip: 'Making your story...'),
        ),
      ),
    ).then((_) {
      // --- THE FIX IS HERE ---
      // When the user presses "Back" and returns to the Home Screen,
      // we must reload the list to get back to 'LessonLoaded' state.
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

    // NOTE: Removed BlocListener because we navigate immediately now.
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
