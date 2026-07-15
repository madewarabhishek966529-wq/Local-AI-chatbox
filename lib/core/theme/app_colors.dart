import 'package:flutter/material.dart';

/// Design tokens for Local — an offline-first AI chat app.
///
/// Palette concept: "signal in the dark". The app never touches the cloud,
/// so the visual language leans into on-device, terminal-adjacent computing
/// rather than the warm/cream or glossy-cloud looks common in AI chat UIs.
/// A single teal "signal" accent stands in for local inference — it appears
/// wherever the app wants to say "this happened on your machine."
class AppColors {
  AppColors._();

  // Surfaces
  static const Color bg = Color(0xFF10131A);
  static const Color surface = Color(0xFF1A1F29);
  static const Color surfaceElevated = Color(0xFF232936);
  static const Color surfaceSunken = Color(0xFF0B0D12);
  static const Color border = Color(0xFF2A3140);
  static const Color borderSubtle = Color(0xFF1F2531);

  // Signal accent (local inference marker, primary CTA)
  static const Color signal = Color(0xFF5EEAD4);
  static const Color signalDim = Color(0xFF2DD4BF);
  static const Color signalMuted = Color(0xFF1E4B47);

  // Secondary accent, used sparingly (favorites, warnings-lite)
  static const Color amber = Color(0xFFF5A962);

  // Text
  static const Color textPrimary = Color(0xFFECEFF3);
  static const Color textSecondary = Color(0xFF8D97A8);
  static const Color textTertiary = Color(0xFF5B6472);

  // Semantic
  static const Color error = Color(0xFFF2555A);
  static const Color errorMuted = Color(0xFF3A2229);
  static const Color success = Color(0xFF5EEAD4);
  static const Color warning = Color(0xFFF5A962);

  // Chat bubbles
  static const Color bubbleUser = Color(0xFF1E4B47); // signal-tinted
  static const Color bubbleUserBorder = Color(0xFF2DD4BF);
  static const Color bubbleAi = Color(0xFF1A1F29);
  static const Color bubbleAiBorder = Color(0xFF2A3140);

  // Code blocks
  static const Color codeBg = Color(0xFF0B0D12);
  static const Color codeBorder = Color(0xFF232936);
}
