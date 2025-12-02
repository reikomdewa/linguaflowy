
// // File: lib/screens/reader/reader_screen.dart

// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:linguaflow/blocs/auth/auth_bloc.dart';
// import 'package:linguaflow/blocs/vocabulary/vocabulary_bloc.dart';
// import 'package:linguaflow/models/lesson_model.dart';
// import 'package:linguaflow/models/user_model.dart';
// import 'package:linguaflow/models/vocabulary_item.dart';
// import 'package:linguaflow/services/translation_service.dart';
// import 'package:linguaflow/services/vocabulary_service.dart';

// class ReaderScreen extends StatefulWidget {
//   final LessonModel lesson;

//   const ReaderScreen({required this.lesson});

//   @override
//   _ReaderScreenState createState() => _ReaderScreenState();
// }

// class _ReaderScreenState extends State<ReaderScreen> {
//   Map<String, VocabularyItem> _vocabulary = {};
//   String? _selectedWord;
//   int _selectedWordIndex = -1;

//   @override
//   void initState() {
//     super.initState();
//     _loadVocabulary();
//   }

//   Future<void> _loadVocabulary() async {
//     final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
//     final vocabService = context.read<VocabularyService>();
//     final items = await vocabService.getVocabulary(user.id);
    
//     setState(() {
//       _vocabulary = {
//         for (var item in items) item.word.toLowerCase(): item
//       };
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text(widget.lesson.title),
//         actions: [
//           IconButton(
//             icon: Icon(Icons.settings),
//             onPressed: () {},
//           ),
//         ],
//       ),
//       body: Column(
//         children: [
//           Container(
//             padding: EdgeInsets.all(16),
//             color: Colors.blue.withOpacity(0.1),
//             child: Row(
//               children: [
//                 Icon(Icons.language, color: Colors.blue),
//                 SizedBox(width: 8),
//                 Text(
//                   widget.lesson.language.toUpperCase(),
//                   style: TextStyle(
//                     fontWeight: FontWeight.bold,
//                     color: Colors.blue,
//                   ),
//                 ),
//                 Spacer(),
//                 Text(
//                   '${widget.lesson.sentences.length} sentences',
//                   style: TextStyle(color: Colors.grey[600]),
//                 ),
//               ],
//             ),
//           ),
//           Expanded(
//             child: SingleChildScrollView(
//               padding: EdgeInsets.all(20),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: widget.lesson.sentences.asMap().entries.map((entry) {
//                   return Padding(
//                     padding: EdgeInsets.only(bottom: 20),
//                     child: _buildSentence(entry.value, entry.key),
//                   );
//                 }).toList(),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildSentence(String sentence, int sentenceIndex) {
//     final words = sentence.split(RegExp(r'(\s+)'));
    
//     return Wrap(
//       children: words.map((word) {
//         final cleanWord = word.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
//         if (cleanWord.isEmpty || word.trim().isEmpty) {
//           return Text(word, style: TextStyle(fontSize: 18));
//         }

//         final vocabItem = _vocabulary[cleanWord];
//         final color = _getWordColor(vocabItem);

//         return GestureDetector(
//           onTap: () => _onWordTap(cleanWord, word, sentenceIndex),
//           child: Container(
//             decoration: BoxDecoration(
//               color: color,
//               borderRadius: BorderRadius.circular(4),
//             ),
//             padding: EdgeInsets.symmetric(horizontal: 2, vertical: 1),
//             child: Text(
//               word,
//               style: TextStyle(
//                 fontSize: 18,
//                 height: 1.6,
//                 color: vocabItem?.status == 5 ? Colors.black87 : null,
//               ),
//             ),
//           ),
//         );
//       }).toList(),
//     );
//   }

//   Color _getWordColor(VocabularyItem? item) {
//     if (item == null) return Colors.blue.withOpacity(0.2);
    
//     switch (item.status) {
//       case 0:
//         return Colors.blue.withOpacity(0.3);
//       case 1:
//         return Colors.yellow.withOpacity(0.3);
//       case 2:
//         return Colors.orange.withOpacity(0.25);
//       case 3:
//         return Colors.orange.withOpacity(0.35);
//       case 4:
//         return Colors.orange.withOpacity(0.45);
//       case 5:
//         return Colors.transparent;
//       default:
//         return Colors.grey.withOpacity(0.2);
//     }
//   }

//   void _onWordTap(String cleanWord, String originalWord, int wordIndex) {
//     setState(() {
//       _selectedWord = cleanWord;
//       _selectedWordIndex = wordIndex;
//     });

//     _showWordDialog(cleanWord, originalWord);
//   }

//   void _showWordDialog(String cleanWord, String originalWord) async {
//     final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
//     final vocabService = context.read<VocabularyService>();
//     final translationService = context.read<TranslationService>();

//     VocabularyItem? existingItem = _vocabulary[cleanWord];
//     String translation = existingItem?.translation ?? 'Loading...';

//     if (existingItem == null) {
//       // Fetch translation
//       translation = await translationService.translate(
//         cleanWord,
//         user.nativeLanguage,
//         widget.lesson.language,
//       );
//     }

//     if (!mounted) return;

//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//       ),
//       builder: (context) => DraggableScrollableSheet(
//         initialChildSize: 0.6,
//         minChildSize: 0.4,
//         maxChildSize: 0.9,
//         expand: false,
//         builder: (context, scrollController) {
//           return SingleChildScrollView(
//             controller: scrollController,
//             child: Padding(
//               padding: EdgeInsets.all(24),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Center(
//                     child: Container(
//                       width: 40,
//                       height: 4,
//                       decoration: BoxDecoration(
//                         color: Colors.grey[300],
//                         borderRadius: BorderRadius.circular(2),
//                       ),
//                     ),
//                   ),
//                   SizedBox(height: 24),
//                   Text(
//                     originalWord,
//                     style: TextStyle(
//                       fontSize: 32,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                   SizedBox(height: 8),
//                   Container(
//                     padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                     decoration: BoxDecoration(
//                       color: Colors.blue.withOpacity(0.1),
//                       borderRadius: BorderRadius.circular(4),
//                     ),
//                     child: Text(
//                       widget.lesson.language.toUpperCase(),
//                       style: TextStyle(
//                         color: Colors.blue,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ),
//                   SizedBox(height: 24),
//                   Text(
//                     'Translation',
//                     style: TextStyle(
//                       fontSize: 14,
//                       color: Colors.grey[600],
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                   SizedBox(height: 8),
//                   Text(
//                     translation,
//                     style: TextStyle(fontSize: 20),
//                   ),
//                   SizedBox(height: 32),
//                   Text(
//                     'Status',
//                     style: TextStyle(
//                       fontSize: 14,
//                       color: Colors.grey[600],
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                   SizedBox(height: 12),
//                   Wrap(
//                     spacing: 8,
//                     runSpacing: 8,
//                     children: [
//                       _StatusButton(
//                         label: 'New',
//                         status: 0,
//                         color: Colors.blue,
//                         onTap: () => _updateWordStatus(
//                           cleanWord,
//                           originalWord,
//                           translation,
//                           0,
//                         ),
//                       ),
//                       _StatusButton(
//                         label: 'Learning 1',
//                         status: 1,
//                         color: Colors.yellow[700]!,
//                         onTap: () => _updateWordStatus(
//                           cleanWord,
//                           originalWord,
//                           translation,
//                           1,
//                         ),
//                       ),
//                       _StatusButton(
//                         label: 'Learning 2',
//                         status: 2,
//                         color: Colors.orange[600]!,
//                         onTap: () => _updateWordStatus(
//                           cleanWord,
//                           originalWord,
//                           translation,
//                           2,
//                         ),
//                       ),
//                       _StatusButton(
//                         label: 'Learning 3',
//                         status: 3,
//                         color: Colors.orange[700]!,
//                         onTap: () => _updateWordStatus(
//                           cleanWord,
//                           originalWord,
//                           translation,
//                           3,
//                         ),
//                       ),
//                       _StatusButton(
//                         label: 'Learning 4',
//                         status: 4,
//                         color: Colors.orange[800]!,
//                         onTap: () => _updateWordStatus(
//                           cleanWord,
//                           originalWord,
//                           translation,
//                           4,
//                         ),
//                       ),
//                       _StatusButton(
//                         label: 'Known',
//                         status: 5,
//                         color: Colors.green,
//                         onTap: () => _updateWordStatus(
//                           cleanWord,
//                           originalWord,
//                           translation,
//                           5,
//                         ),
//                       ),
//                     ],
//                   ),
//                   SizedBox(height: 16),
//                   ElevatedButton.icon(
//                     onPressed: () => _updateWordStatus(
//                       cleanWord,
//                       originalWord,
//                       translation,
//                       -1,
//                     ),
//                     icon: Icon(Icons.block),
//                     label: Text('Ignore Word'),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.grey,
//                       minimumSize: Size(double.infinity, 48),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           );
//         },
//       ),
//     );
//   }

//   void _updateWordStatus(
//     String cleanWord,
//     String originalWord,
//     String translation,
//     int status,
//   ) async {
//     final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
//     final vocabService = context.read<VocabularyService>();

//     VocabularyItem? existingItem = _vocabulary[cleanWord];

//     if (existingItem != null) {
//       final updatedItem = existingItem.copyWith(
//         status: status,
//         timesEncountered: existingItem.timesEncountered + 1,
//       );
//       context.read<VocabularyBloc>().add(VocabularyUpdateRequested(updatedItem));
//       setState(() {
//         _vocabulary[cleanWord] = updatedItem;
//       });
//     } else {
//       final newItem = VocabularyItem(
//         id: '',
//         userId: user.id,
//         word: cleanWord,
//         baseForm: cleanWord,
//         language: widget.lesson.language,
//         translation: translation,
//         status: status,
//         timesEncountered: 1,
//         lastReviewed: DateTime.now(),
//         createdAt: DateTime.now(),
//       );
//       context.read<VocabularyBloc>().add(VocabularyAddRequested(newItem));
//       setState(() {
//         _vocabulary[cleanWord] = newItem;
//       });
//     }

//     Navigator.pop(context);
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text('Word updated!'),
//         duration: Duration(seconds: 1),
//       ),
//     );
//   }
// }

// class _StatusButton extends StatelessWidget {
//   final String label;
//   final int status;
//   final Color color;
//   final VoidCallback onTap;

//   const _StatusButton({
//     required this.label,
//     required this.status,
//     required this.color,
//     required this.onTap,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return ElevatedButton(
//       onPressed: onTap,
//       style: ElevatedButton.styleFrom(
//         backgroundColor: color,
//         foregroundColor: Colors.white,
//       ),
//       child: Text(label),
//     );
//   }
// }
// File: lib/screens/reader/reader_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/vocabulary/vocabulary_bloc.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/models/user_model.dart';
import 'package:linguaflow/models/vocabulary_item.dart';
import 'package:linguaflow/services/translation_service.dart';
import 'package:linguaflow/services/vocabulary_service.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart'; // IMPORT THIS

class ReaderScreen extends StatefulWidget {
  final LessonModel lesson;

  const ReaderScreen({required this.lesson});

  @override
  _ReaderScreenState createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  Map<String, VocabularyItem> _vocabulary = {};
  
  // Video Player State
  YoutubePlayerController? _videoController;
  bool _isVideo = false;

  @override
  void initState() {
    super.initState();
    _loadVocabulary();
    _initializeVideoPlayer();
  }

  @override
  void dispose() {
    // Dispose video controller to free resources
    _videoController?.dispose();
    super.dispose();
  }

  void _initializeVideoPlayer() {
    // 1. Check if lesson type is video or has a video URL
    if (widget.lesson.type == 'video' || widget.lesson.videoUrl != null) {
      String? videoId;

      // 2. Extract ID
      // If it came from our scraper/fallback, ID looks like "yt_abc123"
      if (widget.lesson.id.startsWith('yt_')) {
        videoId = widget.lesson.id.replaceAll('yt_', '');
      } 
      // If it's a direct URL
      else if (widget.lesson.videoUrl != null) {
        videoId = YoutubePlayer.convertUrlToId(widget.lesson.videoUrl!);
      }

      // 3. Initialize Controller
      if (videoId != null) {
        _isVideo = true;
        _videoController = YoutubePlayerController(
          initialVideoId: videoId,
          flags: const YoutubePlayerFlags(
            autoPlay: false,
            mute: false,
            enableCaption: false, // We show our own text below
          ),
        );
      }
    }
  }

  Future<void> _loadVocabulary() async {
    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
    final vocabService = context.read<VocabularyService>();
    final items = await vocabService.getVocabulary(user.id);
    
    setState(() {
      _vocabulary = {
        for (var item in items) item.word.toLowerCase(): item
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.lesson.title),
        actions: [
          IconButton(
            icon: Icon(widget.lesson.isFavorite ? Icons.star : Icons.star_border),
            onPressed: () {
              // Add Favorite Logic here if needed
            },
          ),
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. VIDEO PLAYER (If available) OR IMAGE HEADER
          _buildMediaHeader(),

          // 2. LANGUAGE INFO BAR
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.blue.withOpacity(0.1),
            child: Row(
              children: [
                Icon(Icons.language, color: Colors.blue, size: 20),
                SizedBox(width: 8),
                Text(
                  widget.lesson.language.toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                Spacer(),
                Text(
                  '${widget.lesson.sentences.length} sentences',
                  style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),

          // 3. TEXT CONTENT
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Optional: Show title inside content as well
                  Text(
                    widget.lesson.title,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 20),
                  
                  // Sentences
                  ...widget.lesson.sentences.asMap().entries.map((entry) {
                    return Padding(
                      padding: EdgeInsets.only(bottom: 20),
                      child: _buildSentence(entry.value, entry.key),
                    );
                  }).toList(),
                  
                  // Bottom padding for scrolling
                  SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaHeader() {
    if (_isVideo && _videoController != null) {
      return YoutubePlayer(
        controller: _videoController!,
        showVideoProgressIndicator: true,
        progressIndicatorColor: Colors.red,
        progressColors: const ProgressBarColors(
          playedColor: Colors.red,
          handleColor: Colors.redAccent,
        ),
      );
    } else if (widget.lesson.imageUrl != null && widget.lesson.imageUrl!.isNotEmpty) {
      // Fallback to Image if no video
      return Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          image: DecorationImage(
            image: NetworkImage(widget.lesson.imageUrl!),
            fit: BoxFit.cover,
            onError: (e, s) {}, // Handle image errors silently
          ),
        ),
        // If image fails loading, show title
        child: widget.lesson.imageUrl!.contains('hqdefault') 
            ? null 
            : Center(child: Icon(Icons.image, color: Colors.grey)),
      );
    }
    return SizedBox.shrink();
  }

  Widget _buildSentence(String sentence, int sentenceIndex) {
    // Split by spaces but keep delimiters if possible, 
    // simply splitting by space is okay for basic implementation
    final words = sentence.split(RegExp(r'(\s+)'));
    
    return Wrap(
      children: words.map((word) {
        // Strip punctuation for lookup
        final cleanWord = word.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
        
        // If it's just punctuation or empty, render plain text
        if (cleanWord.isEmpty || word.trim().isEmpty) {
          return Text(word, style: TextStyle(fontSize: 18, height: 1.6));
        }

        final vocabItem = _vocabulary[cleanWord];
        final color = _getWordColor(vocabItem);

        return GestureDetector(
          onTap: () => _onWordTap(cleanWord, word, sentenceIndex),
          child: Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
            // Tiny padding to make background color visible around the word
            padding: EdgeInsets.symmetric(horizontal: 2, vertical: 1),
            child: Text(
              word,
              style: TextStyle(
                fontSize: 18,
                height: 1.6,
                // If word is known (5), keep black. Else allow color logic if you add it later
                color: Colors.black87, 
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Color _getWordColor(VocabularyItem? item) {
    if (item == null) return Colors.blue.withOpacity(0.1); // New words (Default Blue tint)
    
    switch (item.status) {
      case 0: return Colors.blue.withOpacity(0.2); // New / Seen once
      case 1: return Colors.yellow.withOpacity(0.3); // Learning
      case 2: return Colors.orange.withOpacity(0.25);
      case 3: return Colors.orange.withOpacity(0.35);
      case 4: return Colors.orange.withOpacity(0.45);
      case 5: return Colors.transparent; // Known (No background)
      default: return Colors.grey.withOpacity(0.2); // Ignored
    }
  }

  void _onWordTap(String cleanWord, String originalWord, int wordIndex) {
    _showWordDialog(cleanWord, originalWord);
  }

  void _showWordDialog(String cleanWord, String originalWord) async {
    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
    final translationService = context.read<TranslationService>();

    VocabularyItem? existingItem = _vocabulary[cleanWord];
    
    // Optimistic loading state text
    String translation = existingItem?.translation ?? 'Translating...';
    
    // Show dialog immediately
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setModalState) {
          
          // Trigger translation if needed inside the modal builder
          if (existingItem == null && translation == 'Translating...') {
            translationService.translate(
              cleanWord,
              user.nativeLanguage,
              widget.lesson.language,
            ).then((result) {
              if (mounted) {
                setModalState(() {
                  translation = result;
                });
              }
            });
            // Prevent multiple calls
            if (translation == 'Translating...') translation = 'Translating... '; 
          }

          return DraggableScrollableSheet(
            initialChildSize: 0.5,
            minChildSize: 0.4,
            maxChildSize: 0.85,
            builder: (_, controller) => Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: EdgeInsets.all(24),
              child: ListView(
                controller: controller,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  SizedBox(height: 24),
                  Text(originalWord, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('Translation', style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text(translation, style: TextStyle(fontSize: 20)),
                  SizedBox(height: 32),
                  Text('Status', style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.bold)),
                  SizedBox(height: 12),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: [
                      _StatusButton(label: 'New', status: 0, color: Colors.blue, onTap: () => _updateWordStatus(cleanWord, originalWord, translation, 0)),
                      _StatusButton(label: '1', status: 1, color: Colors.yellow[700]!, onTap: () => _updateWordStatus(cleanWord, originalWord, translation, 1)),
                      _StatusButton(label: '2', status: 2, color: Colors.orange[600]!, onTap: () => _updateWordStatus(cleanWord, originalWord, translation, 2)),
                      _StatusButton(label: '3', status: 3, color: Colors.orange[700]!, onTap: () => _updateWordStatus(cleanWord, originalWord, translation, 3)),
                      _StatusButton(label: '4', status: 4, color: Colors.orange[800]!, onTap: () => _updateWordStatus(cleanWord, originalWord, translation, 4)),
                      _StatusButton(label: 'Known', status: 5, color: Colors.green, onTap: () => _updateWordStatus(cleanWord, originalWord, translation, 5)),
                    ],
                  ),
                  SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _updateWordStatus(cleanWord, originalWord, translation, -1),
                    icon: Icon(Icons.block),
                    label: Text('Ignore Word'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.grey, minimumSize: Size(double.infinity, 48)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _updateWordStatus(String cleanWord, String originalWord, String translation, int status) async {
    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
    
    VocabularyItem? existingItem = _vocabulary[cleanWord];

    if (existingItem != null) {
      final updatedItem = existingItem.copyWith(status: status, timesEncountered: existingItem.timesEncountered + 1);
      context.read<VocabularyBloc>().add(VocabularyUpdateRequested(updatedItem));
      setState(() => _vocabulary[cleanWord] = updatedItem);
    } else {
      final newItem = VocabularyItem(
        id: '', userId: user.id, word: cleanWord, baseForm: cleanWord,
        language: widget.lesson.language, translation: translation, status: status,
        timesEncountered: 1, lastReviewed: DateTime.now(), createdAt: DateTime.now(),
      );
      context.read<VocabularyBloc>().add(VocabularyAddRequested(newItem));
      setState(() => _vocabulary[cleanWord] = newItem);
    }

    Navigator.pop(context);
  }
}

class _StatusButton extends StatelessWidget {
  final String label;
  final int status;
  final Color color;
  final VoidCallback onTap;

  const _StatusButton({required this.label, required this.status, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60, // Fixed width for cleaner look
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: EdgeInsets.zero,
        ),
        child: Text(label),
      ),
    );
  }
}