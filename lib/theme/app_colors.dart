import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFFF57C00); // Orange
  static const Color primaryLight = Color(0xFFFFA726);
  static const Color primaryDark = Color(0xFFFB8C00);

  static const Color secondary = Color(0xFF43A047); // Green

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryLight, primaryDark],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
