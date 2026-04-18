import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'constants.dart';

ThemeData veloraTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: VeloraColors.background,
    primaryColor: VeloraColors.cyan,
    colorScheme: const ColorScheme.dark(
      primary: VeloraColors.cyan,
      secondary: VeloraColors.blue,
      surface: VeloraColors.surface,
      error: VeloraColors.red,
    ),
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
    fontFamily: GoogleFonts.inter().fontFamily,
    appBarTheme: const AppBarTheme(
      backgroundColor: VeloraColors.surface,
      elevation: 0,
    ),

    // Fixed: Passing the data class directly to the property
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: VeloraColors.surfaceLight,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none, // Optional: makes it look cleaner
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: VeloraColors.cyan,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
    ),

    // Fixed: CardThemeData for the global theme
    cardTheme: CardThemeData(
      color: VeloraColors.surfaceLight,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: VeloraColors.surfaceLighter, width: 1),
      ),
    ),
  );
}