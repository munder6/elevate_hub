import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

ThemeData buildLightTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorSchemeSeed: const Color(0xFF02A4F4),
  );
  return base.copyWith(
    textTheme: GoogleFonts.cairoTextTheme(base.textTheme),
    scaffoldBackgroundColor: Colors.white,
  );
}
