import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart'; // Required for MD5 Caching
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart'; // Required for Crash Fix
import 'package:path_provider/path_provider.dart';
import 'package:linguaflow/core/env.dart';

class ElevenLabsTtsService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Function? _onComplete;
  
  // ElevenLabs Configuration
  static const String apiKey = Env.elevenLabsApiKey;
  
  // Map languages to best ElevenLabs voices (multilingual model)
  static const Map<String, String> voiceMap = {
    'en': 'EXAVITQu4vr4xnSDxMaL', // Rachel
    'es': 'VR6AewLTigWG4xSOukaG', // Arnold
    'fr': 'XB0fDUnXU5powFXDhCwa', // Charlotte
    'de': 'pNInz6obpgDQGcFmaJgB', // Adam
    'it': 'ErXwobaYiN019PkySvjV', // Antoni
    'pt': 'yoZ06aMxZJJ28mfd3POQ', // Sam
    'ja': 'IKne3meq5aSn9XLyUdCD', // Kazuha
    'ko': '21m00Tcm4TlvDq8ikWAM', // Rachel (Multilingual)
    'zh': 'XrExE9yKIg1WjnnlVkGX', // Matilda
    'ar': 'TxGEqnHWrfWFTfGW9XjX', // Josh
  };

  ElevenLabsTtsService() {
    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _isPlaying = false;
        _onComplete?.call();
      }
    });
  }

  Future<void> speak(String text, String languageCode) async {
    if (apiKey.isEmpty) {
      debugPrint('❌ ElevenLabs: API Key is empty!');
      return;
    }

    try {
      _isPlaying = true;
      final voiceId = voiceMap[languageCode] ?? voiceMap['en']!;
      
      // --- CACHING LOGIC START ---
      // 1. Create a unique, safe filename based on Content + Voice
      final String safeId = md5.convert(utf8.encode("$text-$voiceId")).toString();
      final tempDir = await getTemporaryDirectory();
      final File cacheFile = File('${tempDir.path}/tts_$safeId.mp3');

      // 2. Check if file already exists locally
      if (await cacheFile.exists()) {
        debugPrint("♻️ ElevenLabs: Cache HIT! Playing local file (0 Cost).");
        await _playFile(cacheFile, text);
        return; // EXIT FUNCTION - No API Call made
      }
      // ---------------------------

      debugPrint("☁️ ElevenLabs: Cache MISS. Calling API...");
      final uri = Uri.parse('https://api.elevenlabs.io/v1/text-to-speech/$voiceId');

      final response = await http.post(
        uri,
        headers: {
          'xi-api-key': apiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'text': text,
          'model_id': 'eleven_multilingual_v2',
          'voice_settings': {
            'stability': 0.5,
            'similarity_boost': 0.75,
            'style': 0.0,
            'use_speaker_boost': true,
          }
        }),
      );

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        
        // 3. Save to the unique cache filename
        await cacheFile.writeAsBytes(bytes);
        debugPrint('💾 ElevenLabs: File downloaded and cached.');
        
        await _playFile(cacheFile, text);
      } else {
        _isPlaying = false;
        // Log the actual error from ElevenLabs (e.g., quota_exceeded)
        debugPrint('❌ ElevenLabs API Error Body: ${response.body}');
        throw Exception('ElevenLabs API Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      _isPlaying = false;
      debugPrint('❌ ElevenLabs Service Error: $e');
      rethrow;
    }
  }

  // Helper to play the file safely with MediaItem tag
  Future<void> _playFile(File file, String text) async {
    final source = AudioSource.file(
      file.path,
      // --- CRITICAL FIX: Add MediaItem tag for just_audio_background ---
      tag: MediaItem(
        id: 'elevenlabs_${file.path.hashCode}', // Unique ID based on path
        title: 'Pronunciation',
        artist: 'ElevenLabs',
        extras: {'text': text},
      ),
    );

    await _audioPlayer.setAudioSource(source);
    await _audioPlayer.play();
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
    _isPlaying = false;
  }

  void setCompletionHandler(Function() handler) {
    _onComplete = handler;
  }

  bool get isPlaying => _isPlaying;

  Future<void> dispose() async {
    await _audioPlayer.dispose();
  }
}