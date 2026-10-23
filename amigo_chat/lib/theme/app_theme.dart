import 'package:flutter/material.dart';

class AppColors {
  // Primary palette
  static const Color primary = Color(0xFF6C63FF);
  static const Color primaryLight = Color(0xFF9D97FF);
  static const Color primaryDark = Color(0xFF4A42D4);

  // Background
  static const Color background = Color(0xFFF5F6FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF0F2F5);

  // Chat bubbles
  static const Color myBubble = Color(0xFF6C63FF);
  static const Color myBubbleText = Color(0xFFFFFFFF);
  static const Color otherBubble = Color(0xFFFFFFFF);
  static const Color otherBubbleText = Color(0xFF1A1A2E);

  // Text
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9CA3AF);

  // Status
  static const Color online = Color(0xFF22C55E);
  static const Color offline = Color(0xFF9CA3AF);
  static const Color sent = Color(0xFF9CA3AF);
  static const Color delivered = Color(0xFF60A5FA);
  static const Color read = Color(0xFF6C63FF);

  // Input
  static const Color inputBackground = Color(0xFFF0F2F5);
  static const Color inputBorder = Color(0xFFE5E7EB);
  static const Color sendButton = Color(0xFF6C63FF);

  // Dark mode (future reference)
  static const Color darkBackground = Color(0xFF0F0F1A);
  static const Color darkSurface = Color(0xFF1A1A2E);
  static const Color darkSurfaceVariant = Color(0xFF252540);
}

class AppTextStyles {
  static const TextStyle heading1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w400,
    color: AppColors.textHint,
  );

  static const TextStyle messageMy = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.myBubbleText,
    height: 1.4,
  );

  static const TextStyle messageOther = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.otherBubbleText,
    height: 1.4,
  );
}
