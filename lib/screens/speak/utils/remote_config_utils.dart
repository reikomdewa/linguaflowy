import 'package:firebase_remote_config/firebase_remote_config.dart';

class RemoteConfigUtils {
  static const String _livekitUrlKey = 'livekit_url';
  static const String _fallbackLivekitUrl =
      'wss://fallback.livekit.cloud';

  /// Fetches LiveKit URL from Firebase Remote Config
  /// Safe to call at app start or before joining a room
  static Future<String> getLiveKitUrl({
    bool forceRefresh = false,
  }) async {
    final remoteConfig = FirebaseRemoteConfig.instance;

    await remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 5),
        minimumFetchInterval:
            forceRefresh ? Duration.zero : const Duration(hours: 12),
      ),
    );

    await remoteConfig.setDefaults({
      _livekitUrlKey: _fallbackLivekitUrl,
    });

    await remoteConfig.fetchAndActivate();

    final url = remoteConfig.getString(_livekitUrlKey);

    if (url.isEmpty || !url.startsWith('wss://')) {
      throw Exception(
        'Invalid LiveKit URL from Remote Config: "$url"',
      );
    }

    return url;
  }
}
