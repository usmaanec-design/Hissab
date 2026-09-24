import 'package:flutter/material.dart';

class AppColors {
  // Brand Accents
  static const Color primary = Color(0xFF1E3A8A); // Deep Royal Navy
  static const Color primaryLight = Color(0xFF3B82F6); // Vibrant Azure
  static const Color accent = Color(0xFF0D9488); // Teal Cyan

  // Financial Semantics (Strictly tested for accessibility contrast)
  static const Color moneyIn = Color(0xFF059669); // Emerald Green
  static const Color moneyInContainer = Color(0xFFECFDF5);
  static const Color moneyInDark = Color(0xFF10B981);
  static const Color moneyInContainerDark = Color(0xFF064E3B);

  static const Color moneyOut = Color(0xFFE11D48); // Crimson Ruby
  static const Color moneyOutContainer = Color(0xFFFFF1F2);
  static const Color moneyOutDark = Color(0xFFF43F5E);
  static const Color moneyOutContainerDark = Color(0xFF881337);

  static const Color transfer = Color(0xFF2563EB); // Royal Blue
  static const Color transferContainer = Color(0xFFEFF6FF);

  static const Color warning = Color(0xFFD97706); // Amber
  static const Color warningContainer = Color(0xFFFEF3C7);

  // Light Theme Neutrals
  static const Color lightBg = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);
  static const Color lightTextMuted = Color(0xFF94A3B8);

  // Dark Theme Neutrals (Deep Slate / Obsidian)
  static const Color darkBg = Color(0xFF0B0F17);
  static const Color darkSurface = Color(0xFF111827);
  static const Color darkCard = Color(0xFF1A2234);
  static const Color darkBorder = Color(0xFF2D3748);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextMuted = Color(0xFF64748B);

  // Quick Action Gradients
  static const LinearGradient inGradient = LinearGradient(
    colors: [Color(0xFF059669), Color(0xFF10B981)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient outGradient = LinearGradient(
    colors: [Color(0xFFE11D48), Color(0xFFF43F5E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
