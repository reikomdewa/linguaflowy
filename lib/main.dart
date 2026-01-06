import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:media_kit/media_kit.dart';

// CONFIG
import 'package:linguaflow/firebase_options.dart';
import 'package:linguaflow/core/env.dart';

// APP ENTRY POINT
import 'package:linguaflow/linguaflow_app.dart';

void main() async {
  usePathUrlStrategy(); 
  
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  Env.validate();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  Gemini.init(apiKey: Env.geminiApiKey);

  MediaKit.ensureInitialized();
  
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.ryanheise.bg_demo.channel.audio',
    androidNotificationChannelName: 'Audio playback',
    androidNotificationOngoing: true,
    notificationColor: const Color(0xFF6A11CB),
    androidNotificationIcon: 'mipmap/ic_launcher',
  );

  runApp(const LinguaflowApp());
}


// flutter build web --dart-define-from-file=config.json
// flutter run -d chrome --dart-define-from-file=config.json