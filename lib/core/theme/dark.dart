import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

ThemeData buildDarkTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorSchemeSeed: const Color(0xFF02A4F4),
  );
  return base.copyWith(
    textTheme: GoogleFonts.cairoTextTheme(base.textTheme),
  );
}
