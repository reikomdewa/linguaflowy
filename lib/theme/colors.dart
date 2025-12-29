import 'package:flutter/material.dart';

const String assetImg = 'assets/images/';

class AppColor {
  // --- CORE THEME PALETTE (Private) ---
  static const Color _hyperBlue = Color(0xFF007AFF);
  static const Color _charcoal = Color(0xFF101010);
  static const Color _lightCard = Color(0xFFF9F9F9);
  static const Color _darkCard = Color(0xFF181818);
  static const Color _lightBorder = Color(0xFFE5E5E5);
  static const Color _darkBorder = Color(0xFF262626);

  // --- HELPERS ---
  static bool isDarkMode(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  // ==========================================================
  // DYNAMIC BACKGROUNDS & SURFACES
  // ==========================================================

  static Color homePageBackground(BuildContext context) =>
      isDarkMode(context) ? _charcoal : Colors.white;

  // Maps to your "CardColor" definition
  static Color homePageIcons(BuildContext context) =>
      isDarkMode(context) ? _darkCard : _lightCard;

  static Color homeblack(BuildContext context) => homePageBackground(context);

  // ==========================================================
  // DYNAMIC TEXT COLORS
  // ==========================================================

  static Color homePageTitle(BuildContext context) =>
      isDarkMode(context) ? Colors.white : Colors.black;

  static Color homePageSubtitle(BuildContext context) =>
      isDarkMode(context) ? Colors.grey[400]! : const Color(0xFF414160);

  // For text inside containers/cards
  static Color homePageContainerTextSmall(BuildContext context) =>
      isDarkMode(context) ? Colors.grey[300]! : _charcoal;

  static Color homePageContainerTextBig(BuildContext context) =>
      isDarkMode(context) ? Colors.white : Colors.black;

  // ==========================================================
  // BRANDING & ACCENTS (Aligned to HyperBlue)
  // ==========================================================

  // Replaced the old blue/purple gradients with HyperBlue variations
  static Color gradientFirst = _hyperBlue;
  static Color gradientSecond = const Color(
    0xFF4DAFFF,
  ); // Lighter blue for gradient

  static Color homePageDetail = _hyperBlue;

  static Color homePageContainerTextSmallPro =
      Colors.amber; // Keep amber for "Pro" status

  // ==========================================================
  // STRUCTURAL COLORS (Borders & Dividers)
  // ==========================================================

  static Color homePagePlanColor(BuildContext context) =>
      isDarkMode(context) ? _darkBorder : const Color(0xFFa2a2b1);

  static Color secondPageTopIconColor(BuildContext context) =>
      isDarkMode(context) ? Colors.grey[700]! : const Color(0xFFb7bce8);

  static Color secondPageTitleColor(BuildContext context) =>
      homePageTitle(context);

  static Color secondPageContainerGradient1stColor = _hyperBlue.withOpacity(
    0.8,
  );
  static Color secondPageContainerGradient2ndColor = _hyperBlue.withOpacity(
    0.6,
  );

  static Color secondPageIconColor(BuildContext context) =>
      isDarkMode(context) ? Colors.white : const Color(0xFFfafafe);

  // Mapped to Borders for consistency
  static Color loopColor(BuildContext context) =>
      isDarkMode(context) ? _darkBorder : const Color(0xFF6d8dea);
  static Color setsColor(BuildContext context) =>
      isDarkMode(context) ? Colors.grey[600]! : const Color(0xFF9999a9);
  static Color circuitsColor(BuildContext context) =>
      isDarkMode(context) ? _darkCard : const Color(0xFF2f2f51);

  // ==========================================================
  // LEGACY CONSTANTS (Remapped to Theme)
  // ==========================================================

  static Color kBackgroundColor(BuildContext context) =>
      homePageBackground(context);

  // Mapped "Primary Light" to a subtle blue tint or dark grey
  static Color kPrimaryLight(BuildContext context) =>
      isDarkMode(context) ? _darkCard : const Color(0xFFEDF6F3);

  static Color kPrimary(BuildContext context) =>
      isDarkMode(context) ? _darkBorder : const Color(0xFFDAEFE8);

  static const Color kPrimaryDark = Color(0xFF005ECB); // Darker HyperBlue
  static const Color kAccentColor = _hyperBlue; // Unified accent

  static Color kFontColor(BuildContext context) => homePageTitle(context);
  static Color kFontLightColor(BuildContext context) =>
      homePageSubtitle(context);

  // Kept distinct colors but ensured they look okay on Dark mode
  static const Color turquoise = Color(0xFF81D0BB);
  static const Color thistle = Color(0xFFD0C9E8);
  static const Color kprimaryGreen = Color(0xFF416D6D);

  // Standard definitions
  static const Color primary = _hyperBlue;
  static const Color secondary = _charcoal;

  static Color background(BuildContext context) => homePageBackground(context);

  static const Color textWhite = Colors.white;
  static const Color textBlack = Colors.black;
  static const Color grey = Color(0xFF707070);

  static Color myThemGrey(BuildContext context) =>
      isDarkMode(context) ? _darkBorder : const Color(0xFFEEEEEE);

  static const Color progressColor = _hyperBlue;

  // Community / Web Specifics
  static const Color mobileBackgroundColor = _charcoal;
  static const Color webBackgroundColor = _charcoal;
  static const Color mobileSearchColor = _darkCard;
  static const Color blueColor = _hyperBlue;
  static const Color primaryColor = Colors.white;
  static const Color secondaryColor = Colors.grey;
}

// ==========================================================
// DYNAMIC SHADOWS
// ==========================================================

List<BoxShadow> getShadowList(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return [
    BoxShadow(
      color: isDark
          ? Colors.black.withOpacity(
              0.5,
            ) // Darker, subtler shadow for dark mode
          : Colors.grey[200]!, // Soft shadow for light mode
      blurRadius: 30,
      offset: const Offset(0, 10),
    ),
  ];
}
