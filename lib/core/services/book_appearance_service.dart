import 'package:flutter/material.dart';

/// Service managing book color palettes, contrast readability, and dynamic theme styling.
class BookAppearanceService {
  /// Curated palette of rich, modern, and accessible book colors.
  static const List<int> palette = [
    0xFF2563EB, // Sapphire Blue (Default)
    0xFF059669, // Emerald Green
    0xFFD97706, // Amber Gold
    0xFF7C3AED, // Royal Violet
    0xFFDC2626, // Crimson Ruby
    0xFF0D9488, // Deep Teal
    0xFF4F46E5, // Indigo Night
    0xFFE11D48, // Rose Red
    0xFF0284C7, // Ocean Cyan
    0xFF78716C, // Bronze Stone
  ];

  static const int defaultColor = 0xFF2563EB;

  /// Returns true if the background is dark, meaning foreground text should be light/white.
  static bool isDark(Color color) {
    return color.computeLuminance() < 0.45;
  }

  /// Calculates high-contrast text color for optimal accessibility against any book background.
  static Color getContrastTextColor(Color background) {
    return isDark(background) ? Colors.white : const Color(0xFF1E293B);
  }

  /// Calculates a secondary/subtitle color with appropriate contrast.
  static Color getContrastSubtextColor(Color background) {
    return isDark(background)
        ? Colors.white.withAlpha(200)
        : const Color(0xFF475569);
  }

  /// Generates a rich, subtle linear gradient for top dashboard banners and cards.
  static LinearGradient getBannerGradient(Color primary) {
    final hsl = HSLColor.fromColor(primary);
    final darker = hsl.withLightness((hsl.lightness - 0.12).clamp(0.1, 0.9)).toColor();
    final lighter = hsl.withLightness((hsl.lightness + 0.08).clamp(0.1, 0.9)).toColor();

    return LinearGradient(
      colors: [darker, primary, lighter],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  /// Extracts the initial character for fallback avatar generation.
  static String getInitial(String? name) {
    if (name == null || name.trim().isEmpty) return 'B';
    final trimmed = name.trim();
    // Return first character uppercase
    return trimmed.characters.first.toUpperCase();
  }
}
