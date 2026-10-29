import 'package:flutter/material.dart';

class GameColors {
  // Backgrounds
  static const Color bgPlayfield = Color(0xFF13154A);
  static const Color bgDarkPlayfield = Color(0xFF0D0F35);
  static const Color bgHud = Color(0xFF2E3070);
  
  // UI Pills
  static const Color pillFill = Color(0xFF1A1D5C);
  static const Color pillBorder = Color(0xFF4D3BC6);
  static const Color plusBlue = Color(0xFF2F6DF0);
  static const Color plusBlueBorder = Color(0xFF8FB4FF);
  static const Color plusBlueDark = Color(0xFF1852B8);
  
  // Actions
  static const Color levelPill = Color(0xFF2E8BF0);
  static const Color levelPillDark = Color(0xFF1963C6);
  static const Color startBlue = Color(0xFF2F7BF0);
  static const Color startBlueDark = Color(0xFF1852B8);
  static const Color recoveryIndigo = Color(0xFF4A52CC);
  static const Color recoveryDark = Color(0xFF333A9D);
  static const Color floorLine = Colors.white;

  // Blocks
  static const List<Color> blockColors = [
    Color(0xFFFF2D8D), // Pink
    Color(0xFFFF7A0E), // Orange
    Color(0xFFFDBD10), // Yellow
    Color(0xFF5FBF2B), // Green
    Color(0xFF7A2EDB), // Purple
    Color(0xFF0B86EA), // Blue
  ];

  static const List<Color> blockShades = [
    Color(0xFFC81467),
    Color(0xFFC85705),
    Color(0xFFC69004),
    Color(0xFF448D1D),
    Color(0xFF571B9F),
    Color(0xFF0761AB),
  ];

  // Orbs
  static const Color orbCoreStart = Color(0xFFFFB347);
  static const Color orbCoreEnd = Color(0xFFE8420E);
  static const Color orbRim = Color(0xFFFFD54A);

  // Chest
  static const Color chestTrack = Color(0xFF8D5024);
  static const Color chestFill = Color(0xFF29B6F6);
  static const Color chestCube = Color(0xFFFFC107);
  static const Color chestCubeBorder = Color(0xFF9C27B0);

  // Currencies & Energy
  static const Color cashGreen = Color(0xFF4CAF50);
  static const Color gemBlue = Color(0xFF29B6F6);
  static const Color heartRed = Color(0xFFE8283C);

  // FX Star burst colors
  static const List<Color> fxStarColors = [
    Color(0xFFFF7BAC),
    Color(0xFF4FD1C5),
    Color(0xFF8BD450),
    Color(0xFFFF9F43),
    Color(0xFF5AA9FF),
    Color(0xFFB37BFF),
    Color(0xFFFFE15A),
  ];

  // Lightning
  static const Color lightningCore = Colors.white;
  static const Color lightningGlow = Color(0xFFFFE15A);
}
