// lib/services/eleven_labs_tts_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart'; // Add crypto: ^3.0.3 to pubspec.yaml
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart'; // Add this package
import 'package:linguaflow/utils/language_helper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:linguaflow/core/env.dart';

class ElevenLabsTtsService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Function? _onComplete;
  int _currentRequestId =
      0; // Tracks the active request to prevent race conditions

  static const String apiKey = Env.elevenLabsApiKey;

  static const Map<String, String> voiceMap = {
    'en': 'EXAVITQu4vr4xnSDxMaL',
    'es': 'VR6AewLTigWG4xSOukaG',
    'fr': 'XB0fDUnXU5powFXDhCwa',
    'de': 'pNInz6obpgDQGcFmaJgB',
    'it': 'ErXwobaYiN019PkySvjV',
    'pt': 'yoZ06aMxZJJ28mfd3POQ',
    'ja': 'IKne3meq5aSn9XLyUdCD',
    'ko': '21m00Tcm4TlvDq8ikWAM',
    'zh': 'XrExE9yKIg1WjnnlVkGX',
    'ar': 'TxGEqnHWrfWFTfGW9XjX',
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
    if (apiKey.isEmpty) return;

    _currentRequestId++;
    final int myRequestId = _currentRequestId;

    try {
      _isPlaying = true;

      // --- FIX: USE LANGUAGE HELPER ---
      // 1. Resolve the code (e.g., 'fr-FR' -> 'fr', 'French' -> 'fr')
      String resolvedCode = LanguageHelper.getLangCode(languageCode);

      // 2. Select Voice (Fallback to 'en' if specific code not in OUR map)
      final voiceId = voiceMap[resolvedCode] ?? voiceMap['en']!;

      debugPrint(
        "🗣️ ElevenLabs: Input: '$languageCode' -> Resolved: '$resolvedCode' -> VoiceID: $voiceId",
      );
      // ------------------------------------

      // --- CACHING LOGIC ---
      final String safeId = md5
          .convert(utf8.encode("$text-$voiceId"))
          .toString();
      final tempDir = await getTemporaryDirectory();
      final File cacheFile = File('${tempDir.path}/tts_$safeId.mp3');

      if (await cacheFile.exists()) {
        if (myRequestId != _currentRequestId) return;
        debugPrint("♻️ ElevenLabs: Cache HIT!");
        await _playFile(cacheFile, text, myRequestId);
        return;
      }
      // ---------------------

      final uri = Uri.parse(
        'https://api.elevenlabs.io/v1/text-to-speech/$voiceId',
      );

      final response = await http.post(
        uri,
        headers: {'xi-api-key': apiKey, 'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': text,
          'model_id': 'eleven_multilingual_v2',
          'voice_settings': {
            'stability': 0.5,
            'similarity_boost': 0.75,
            'style': 0.0,
            'use_speaker_boost': true,
          },
        }),
      );

      if (myRequestId != _currentRequestId) return;

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        await cacheFile.writeAsBytes(bytes);
        await _playFile(cacheFile, text, myRequestId);
      } else {
        _isPlaying = false;
        debugPrint('❌ ElevenLabs API Error: ${response.body}');
        return;
      }
    } catch (e) {
      if (myRequestId == _currentRequestId) {
        _isPlaying = false;
        debugPrint('❌ ElevenLabs Service Error: $e');
        rethrow;
      }
    }
  }

  Future<void> _playFile(File file, String text, int requestId) async {
    // Final check before playing
    if (requestId != _currentRequestId) return;

    try {
      final source = AudioSource.file(
        file.path,
        tag: MediaItem(
          id: 'elevenlabs_${file.path.hashCode}',
          title: 'Pronunciation',
          artist: 'ElevenLabs',
          extras: {'text': text},
        ),
      );

      await _audioPlayer.setAudioSource(source);
      await _audioPlayer.play();
    } catch (e) {
      // Ignore interruption errors caused by rapid switching
      if (e.toString().contains("interrupted") || e.toString().contains("-10"))
        return;
      rethrow;
    }
  }

  Future<void> stop() async {
    _currentRequestId++; // Invalidate pending downloads
    if (_audioPlayer.playing) {
      await _audioPlayer.stop();
    }
    _isPlaying = false;
  }

  void setCompletionHandler(Function() handler) {
    _onComplete = handler;
  }

  Future<void> dispose() async {
    await _audioPlayer.dispose();
  }
}
