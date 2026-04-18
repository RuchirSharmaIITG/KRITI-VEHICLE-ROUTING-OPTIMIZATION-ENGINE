import 'package:flutter/material.dart';

// ── API (same as web) ──
const String apiEndpoint = 'http://35.208.133.51:5555/upload';
const String osrmBaseUrl = 'https://router.project-osrm.org/route/v1/driving';

// ── Vehicle colours (mirrors getVehicleColor in ControlPanel.js) ──
const List<Color> vehicleColors = [
  Color(0xFF22D3EE), // cyan
  Color(0xFFA855F7), // purple
  Color(0xFFF472B6), // pink
  Color(0xFFFBBF24), // yellow
  Color(0xFF34D399), // emerald
  Color(0xFFF87171), // red
];

Color getVehicleColor(int index) => vehicleColors[index % vehicleColors.length];

const List<Color> routeColorsGlobe = [
  Color(0x9922D3EE),
  Color(0x99C084FC),
  Color(0x99DB2777),
  Color(0x99FACC15),
];

// ── Theme colours ──
class VeloraColors {
  static const Color background    = Color(0xFF020617); // slate-950
  static const Color surface       = Color(0xFF0F172A); // slate-900
  static const Color surfaceLight  = Color(0xFF1E293B); // slate-800
  static const Color surfaceLighter= Color(0xFF334155); // slate-700
  static const Color border        = Color(0xFF1E293B);
  static const Color borderCyan    = Color(0x4D22D3EE);
  static const Color cyan          = Color(0xFF22D3EE);
  static const Color cyanDark      = Color(0xFF0891B2);
  static const Color blue          = Color(0xFF3B82F6);
  static const Color emerald       = Color(0xFF34D399);
  static const Color purple        = Color(0xFFA855F7);
  static const Color pink          = Color(0xFFF472B6);
  static const Color yellow        = Color(0xFFFBBF24);
  static const Color red           = Color(0xFFF87171);
  static const Color textPrimary   = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF94A3B8); // slate-400
  static const Color textMuted     = Color(0xFF64748B); // slate-500
  static const Color textCyan      = Color(0xFF22D3EE);
}

// ── Misc ──
const int simulationDurationMs = 12000;
const double defaultLat  = 12.9716;
const double defaultLng  = 77.5946;
const double defaultZoom = 13.0;
