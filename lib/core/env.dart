class Env {
  // We use static const because we want these values to be
  // "baked in" at compile time.


  // static const String stripePublishableKey = String.fromEnvironment('STRIPE_KEY');
  // static const String backendUrl = String.fromEnvironment('BACKEND_URL');
  static const String youtubeApiKey = String.fromEnvironment('YOUTUBE_API_KEY');
  static const String geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const String paypalClientId = String.fromEnvironment(
    'PAYPAL_CLIENT_ID',
  );
  static const String livekitUrl = String.fromEnvironment('LIVEKIT_URL');
  static const String liveApikey = String.fromEnvironment('LIVEKIT_API_KEY');
  static const String liveApiSecret = String.fromEnvironment(
    'LIVEKIT_API_SECRET',
  );

  // Add a helper to check if keys are missing during development
  static void validate() {
    if (geminiApiKey.isEmpty) {
      throw Exception(
        'Missing GEMINI_KEY. Did you forget to add --dart-define?',
      );
    }
  }
}
