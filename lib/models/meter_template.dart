import 'package:flutter/material.dart';

class MeterTemplate {
  final String id;
  final String name;
  final Color displayColor;
  final bool hasBg;
  final double fontSize;
  final double letterSpacing;

  const MeterTemplate({
    required this.id,
    required this.name,
    required this.displayColor,
    required this.hasBg,
    required this.fontSize,
    required this.letterSpacing,
  });

  static const List<MeterTemplate> presets = [
    MeterTemplate(
      id: 'lcd_green',
      name: 'LCD Green',
      displayColor: Color(0xFF4CAF50),
      hasBg: true,
      fontSize: 34,
      letterSpacing: 3,
    ),
    MeterTemplate(
      id: 'lcd_amber',
      name: 'LCD Amber',
      displayColor: Color(0xFFFFBF00),
      hasBg: true,
      fontSize: 34,
      letterSpacing: 3,
    ),
    MeterTemplate(
      id: 'white_led',
      name: 'White LED',
      displayColor: Colors.white,
      hasBg: false,
      fontSize: 36,
      letterSpacing: 2,
    ),
    MeterTemplate(
      id: 'cyan_digital',
      name: 'Cyan Digital',
      displayColor: Color(0xFF00E5FF),
      hasBg: true,
      fontSize: 32,
      letterSpacing: 4,
    ),
    MeterTemplate(
      id: 'red_display',
      name: 'Red Display',
      displayColor: Color(0xFFFF5252),
      hasBg: true,
      fontSize: 34,
      letterSpacing: 3,
    ),
    MeterTemplate(
      id: 'blue_matrix',
      name: 'Blue Matrix',
      displayColor: Color(0xFF448AFF),
      hasBg: true,
      fontSize: 30,
      letterSpacing: 5,
    ),
  ];
}
