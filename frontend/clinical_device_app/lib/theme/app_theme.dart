import 'package:flutter/material.dart';

class AppTheme {
  static const clinicalGreen = Color(0xFF2E7D32);
  static const clinicalRed = Color(0xFFC62828);
  static const clinicalAmber = Color(0xFFF9A825);
  static const clinicalBlue = Color(0xFF1565C0);

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: clinicalBlue,
        brightness: Brightness.light,
      ),
    );
    return base.copyWith(
      appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
      cardTheme: CardThemeData(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: clinicalBlue,
        brightness: Brightness.dark,
      ),
    );
    return base.copyWith(
      appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
      cardTheme: CardThemeData(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  static Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'online':
        return clinicalGreen;
      case 'alert':
        return clinicalRed;
      default:
        return Colors.grey;
    }
  }

  static Color severityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return clinicalRed;
      case 'warning':
        return clinicalAmber;
      default:
        return clinicalBlue;
    }
  }
}
