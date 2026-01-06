import 'dart:async';
import 'package:flutter/material.dart';

class QuizLoadingView extends StatefulWidget {
  final String languageName;
  final String flag;

  const QuizLoadingView({
    super.key,
    required this.languageName,
    required this.flag,
  });

  @override
  State<QuizLoadingView> createState() => _QuizLoadingViewState();
}

class _QuizLoadingViewState extends State<QuizLoadingView> {
  int _currentTipIndex = 0;
  Timer? _timer;
  late final List<String> _tips;

  @override
  void initState() {
    super.initState();
    _tips = [
      "Speaking ${widget.languageName} ${widget.flag} out loud helps memory.",
      "Don't worry about mistakes in ${widget.languageName}.",
      "Try to think in ${widget.languageName} for 1 minute a day.",
      "Immersion is key! Watch videos in ${widget.languageName}.",
      "Spaced Repetition helps move words to long-term memory.",
      "Label items in your house with post-it notes in ${widget.languageName}.",
      "Switch your phone's language to ${widget.languageName}.",
    ];
    _tips.shuffle();
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted) {
        setState(() => _currentTipIndex = (_currentTipIndex + 1) % _tips.length);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "${widget.flag} Loading...",
              style: TextStyle(fontSize: 24, color: Colors.grey[400]),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 100,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child: Text(
                  _tips[_currentTipIndex],
                  key: ValueKey<int>(_currentTipIndex),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}