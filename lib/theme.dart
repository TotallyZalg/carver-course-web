import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const darkBrown = Color(0xFF4A1A05);
  static const sidebar = Color(0xFF8B3A10);
  static const orange = Color(0xFFD9753F);
  static const label = Color(0xFF9A3B0E);
  static const title = Color(0xFF5A2A0A);
  static const cardCream = Color(0xFFF5EBD3);
  static const cardBorder = Color(0xFFE6C9A0);
  static const formCard = Color(0xFFFFF5F8);
  static const inputFill = Color(0xFFF7F3EC);
  static const cream = Color(0xFFFFF3E0);
  static const taskSquare = Color(0xFFC49A7A);
}

class AppText {
  static TextStyle serif({double size = 16, Color? color, FontWeight? weight, double? spacing}) =>
      GoogleFonts.lora(fontSize: size, color: color, fontWeight: weight, letterSpacing: spacing);

  static TextStyle sans({double size = 12, Color? color, FontWeight? weight, double? spacing}) =>
      GoogleFonts.outfit(fontSize: size, color: color, fontWeight: weight, letterSpacing: spacing);
}