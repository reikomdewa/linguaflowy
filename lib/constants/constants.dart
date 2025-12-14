// lib/utils/app_constants.dart

class AppConstants {
  // Private constructor to prevent instantiation
  AppConstants._();

  static const List<String> adminEmails = [
    "tester_email@gmail.com",
    "reikomuk@gmail.com",
    "developer@linguaflow.app", // Example
  ];

  /// Helper method to check if an email is admin
  static bool isAdmin(String email) {
    return adminEmails.contains(email);
  }
}

