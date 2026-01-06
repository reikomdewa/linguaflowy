class Env {
  // We use static const because we want these values to be
  // "baked in" at compile time.

  // static const String stripePublishableKey = String.fromEnvironment('STRIPE_KEY');
  // static const String backendUrl = String.fromEnvironment('BACKEND_URL');
  static const String youtubeApiKey = String.fromEnvironment('YOUTUBE_API_KEY');
  static const String geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const String googleCloudApiKey = String.fromEnvironment('GOOGLE_CLOUD_API_KEY');
  static const String elevenLabsApiKey = String.fromEnvironment('ELEVEN_LABS_API_KEY');
  static const String paypalClientId = String.fromEnvironment(
    'PAYPAL_CLIENT_ID',
  );

  // Add a helper to check if keys are missing during development
  static void validate() {
    if (geminiApiKey.isEmpty) {
      throw Exception(
        'Missing GEMINI_KEY. Did you forget to add --dart-define?',
      );
    }
      if (elevenLabsApiKey.isEmpty) {
      throw Exception(
        'Missing ELEVEN_LABS_KEY. Did you forget to add --dart-define?',
      );
    }
  }
}
