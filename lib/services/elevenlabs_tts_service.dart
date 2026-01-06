import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:linguaflow/core/env.dart';
import 'package:linguaflow/utils/language_helper.dart';

class ElevenLabsTtsService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Function? _onComplete;
  int _currentRequestId = 0;
  
  static const String apiKey = Env.elevenLabsApiKey;
  
  static const Map<String, String> voiceMap = {
    'en': 'EXAVITQu4vr4xnSDxMaL',
    'es': 'ErXwobaYiN019PkySvjV', 
    'fr': 'XB0fDUnXU5powFXDhCwa',
    'de': 'pNInz6obpgDQGcFmaJgB', 
    'it': 'ErXwobaYiN019PkySvjV', 
    'pt': 'yoZ06aMxZJJ28mfd3POQ', 
    'ja': 'IKne3meq5aSn9XLyUdCD', 
    'zh': 'XrExE9yKIg1WjnnlVkGX', 
    'ar': 'TxGEqnHWrfWFTfGW9XjX', 
    'ru': 'iP95p4xoKVk53GoZ742B', 
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
      debugPrint("❌ ElevenLabs: API Key is missing!");
      return;
    }

    _currentRequestId++; 
    final int myRequestId = _currentRequestId; 

    try {
      _isPlaying = true;

      debugPrint("\n--- 🔍 ELEVENLABS DEBUG LOG ---");
      debugPrint("1. Input Text: '$text'");
      debugPrint("2. Raw Language Code: '$languageCode'");

      // 1. Resolve Language Code
      String resolvedCode = LanguageHelper.getLangCode(languageCode);
      debugPrint("3. Resolved ISO Code: '$resolvedCode'");
      
      // 2. Load User Preference
      final prefs = await SharedPreferences.getInstance();
      final String? savedVoiceId = prefs.getString('elevenlabs_voice_id_$resolvedCode');

      String voiceId;
      if (savedVoiceId != null && savedVoiceId.isNotEmpty) {
        voiceId = savedVoiceId;
        debugPrint("4. Voice Selection: User Preference ($voiceId)");
      } else {
        voiceId = voiceMap[resolvedCode] ?? voiceMap['en']!;
        debugPrint("4. Voice Selection: Default Map ($voiceId)");
      }

      // 3. FORCE TURBO v2.5
      const String modelId = 'eleven_turbo_v2_5';

      // 4. CACHING LOGIC
      // CRITICAL UPDATE: We add 'resolvedCode' to the hash. 
      // If we previously cached a file without the language code (which read as English),
      // this new hash will be different, forcing a new download with the correct accent.
      final String safeId = md5.convert(utf8.encode("$text-$voiceId-$modelId-$resolvedCode")).toString();
      final tempDir = await getTemporaryDirectory();
      final File cacheFile = File('${tempDir.path}/tts_$safeId.mp3');

      if (await cacheFile.exists()) {
        if (myRequestId != _currentRequestId) return; 
        debugPrint("✅ Cache HIT! Playing local file: ${cacheFile.path}");
        debugPrint("-------------------------------\n");
        await _playFile(cacheFile, text, myRequestId);
        return; 
      }

      debugPrint("☁️ Cache MISS. Preparing API Call...");

      // 5. API Call
      final uri = Uri.parse('https://api.elevenlabs.io/v1/text-to-speech/$voiceId');
      
      final Map<String, dynamic> requestBody = {
        'text': text,
        'model_id': modelId,
        'language_code': resolvedCode, // <--- VERIFY THIS IN LOGS
        'voice_settings': {
          'stability': 0.5,
          'similarity_boost': 0.75,
          'style': 0.0,
          'use_speaker_boost': true,
        }
      };

      // PRINT THE EXACT JSON BEING SENT
      debugPrint("5. Sending JSON payload: ${jsonEncode(requestBody)}");

      final response = await http.post(
        uri,
        headers: {
          'xi-api-key': apiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      if (myRequestId != _currentRequestId) return;

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        await cacheFile.writeAsBytes(bytes);
        debugPrint("✅ Download Complete. Size: ${bytes.length} bytes.");
        debugPrint("-------------------------------\n");
        await _playFile(cacheFile, text, myRequestId);
      } else {
        _isPlaying = false;
        debugPrint("❌ API ERROR: ${response.statusCode}");
        debugPrint("❌ Response Body: ${response.body}");
        debugPrint("-------------------------------\n");
        return; 
      }
    } catch (e) {
      if (myRequestId == _currentRequestId) {
        _isPlaying = false;
        debugPrint("❌ Exception: $e");
        rethrow; 
      }
    }
  }

  Future<void> _playFile(File file, String text, int requestId) async {
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
       if (e.toString().contains("interrupted") || e.toString().contains("-10")) return;
       rethrow;
    }
  }

  Future<void> stop() async {
    _currentRequestId++; 
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