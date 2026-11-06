import 'package:flutter/material.dart';

/// Shared pink palette for the Order Display interface.
abstract final class AppColors {
  static const primary = Color(0xFFC00050);
  static const primaryDark = Color(0xFF94003E);
  static const primaryMuted = Color(0xFF8A3C61);
  static const primarySoft = Color(0xFFF5D1E2);

  static const canvas = Color(0xFFFFF0F6);
  static const surface = Color(0xFFFFF6FA);
  static const surfaceRaised = Color(0xFFFFFBFD);
  static const outline = Color(0xFFE8BFD4);

  static const text = Color(0xFF28131F);
  static const mutedText = Color(0xFF704A5D);
  static const disabled = Color(0xFFD6A4BA);
}

/// Button styles that keep primary actions aligned with the brand pink.
abstract final class AppButtonStyles {
  static const filled = ButtonStyle(
    backgroundColor: WidgetStatePropertyAll(AppColors.primary),
    foregroundColor: WidgetStatePropertyAll(Colors.white),
  );

  static const outlined = ButtonStyle(
    foregroundColor: WidgetStatePropertyAll(AppColors.primary),
    side: WidgetStatePropertyAll(BorderSide(color: AppColors.primary)),
  );

  static const text = ButtonStyle(
    foregroundColor: WidgetStatePropertyAll(AppColors.primary),
  );
}
