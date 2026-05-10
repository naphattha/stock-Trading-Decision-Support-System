import 'package:flutter/material.dart';

class AppConfig {
  AppConfig._();

  // ── API URLs (injected at build time via --dart-define) ───────────────────
  // Local dev:    flutter run -d chrome
  // Production:   flutter build web --dart-define=API_URL=https://your-app.onrender.com
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:8000',
  );
  static const String wsUrl = String.fromEnvironment(
    'WS_URL',
    defaultValue: 'ws://localhost:8000/ws/signals',
  );

  // ── Palette ────────────────────────────────────────────────────────────────
  static const Color bgDeep        = Color(0xFF080C18);
  static const Color bgCard        = Color(0xFF111827);
  static const Color bgCardAlt     = Color(0xFF1A2236);
  static const Color accent        = Color(0xFF00C2FF);
  static const Color buy           = Color(0xFF00D26A);
  static const Color sell          = Color(0xFFFF4757);
  static const Color hold          = Color(0xFFFFAA00);
  static const Color universe      = Color(0xFF8B5CF6);
  static const Color checklist     = Color(0xFF06B6D4);
  static const Color portfolio     = Color(0xFF10B981);
  static const Color textPrimary   = Color(0xFFE8EDF5);
  static const Color textSecondary = Color(0xFF7A8599);
  static const Color border        = Color(0xFF1E2D45);

  // ── Helpers ────────────────────────────────────────────────────────────────
  static Color signalColor(String? s) {
    switch (s) { case 'BUY': return buy; case 'SELL': return sell; default: return hold; }
  }
  static String signalEmoji(String? s) {
    switch (s) { case 'BUY': return '🟢'; case 'SELL': return '🔴'; default: return '🟡'; }
  }
  static Color statusColor(String? s) {
    switch (s) {
      case 'WAITING':   return hold;
      case 'TRIGGERED': return buy;
      case 'BOUGHT':    return accent;
      case 'EXPIRED':   return textSecondary;
      default:          return textSecondary;
    }
  }
}
