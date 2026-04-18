import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/map_data.dart';
import '../services/api_service.dart';

class AppState extends ChangeNotifier {
  // ── View state ──
  String _view = 'landing';
  String get view => _view;

  String _activeTab = 'map';
  String get activeTab => _activeTab;

  // ── File ──
  String? _fileName;
  Uint8List? _fileBytes;
  String? get fileName => _fileName;
  Uint8List? get fileBytes => _fileBytes;
  bool get hasFile => _fileBytes != null;

  // ── Optimization level (NEW — mirrors web app select) ──
  String _optimizationLevel = 'optimal'; // 'ultra_fast' | 'fast' | 'optimal'
  String get optimizationLevel => _optimizationLevel;

  int get optimizationLevelValue {
    if (_optimizationLevel == 'ultra_fast') return 10;
    if (_optimizationLevel == 'fast') return 20;
    return 60; // optimal
  }

  void setOptimizationLevel(String level) {
    _optimizationLevel = level;
    notifyListeners();
  }

  // ── Processing ──
  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  bool _loading = false;
  bool get loading => _loading;

  String _statusMsg = 'Waiting...';
  String get statusMsg => _statusMsg;

  String? _errorMsg;
  String? get errorMsg => _errorMsg;

  // ── Data ──
  MapData _mapData = MapData(totalScore: 0);
  MapData get mapData => _mapData;

  OptimizationStats? _stats;
  OptimizationStats? get stats => _stats;

  // ── Vehicle selection & simulation ──
  int? _selectedVehicleIndex;
  int? get selectedVehicleIndex => _selectedVehicleIndex;

  int? _simulatingVehicleIndex;
  int? get simulatingVehicleIndex => _simulatingVehicleIndex;

  // ─────────────────────────────────────────
  //  PUBLIC ACTIONS
  // ─────────────────────────────────────────

  void setFile(String name, Uint8List bytes) {
    _fileName = name;
    _fileBytes = bytes;
    notifyListeners();
  }

  void setActiveTab(String tab) {
    _activeTab = tab;
    notifyListeners();
  }

  void handleProceed() {
    if (_fileBytes == null) return;
    _isProcessing = true;
    notifyListeners();
    Future.delayed(const Duration(milliseconds: 800), () {
      _isProcessing = false;
      _view = 'dashboard';
      notifyListeners();
    });
  }

  void selectVehicle(int? index) {
    _selectedVehicleIndex = index;
    if (_selectedVehicleIndex != _simulatingVehicleIndex) {
      _simulatingVehicleIndex = null;
    }
    notifyListeners();
  }

  void handleSimulate(int index) {
    _selectedVehicleIndex = index;
    _simulatingVehicleIndex = index;
    notifyListeners();
  }

  void handleSimulationEnd() {
    _simulatingVehicleIndex = null;
    notifyListeners();
  }

  void resetApp() {
    // Mirrors web's window.location.reload() — full clean state reset
    _fileName = null;
    _fileBytes = null;
    _mapData = MapData(totalScore: 0);
    _selectedVehicleIndex = null;
    _simulatingVehicleIndex = null;
    _view = 'landing';
    _activeTab = 'map';
    _loading = false;
    _isProcessing = false;
    _statusMsg = 'Waiting...';
    _errorMsg = null;
    _stats = null;
    _optimizationLevel = 'optimal';
    notifyListeners();
  }

  Future<void> handleUploadAndOptimize() async {
    if (_fileBytes == null) return;
    _loading = true;
    _statusMsg = 'Reading Excel...';
    _errorMsg = null;
    notifyListeners();

    try {
      final result = await ApiService.processFile(
        fileBytes: _fileBytes!,
        fileName: _fileName ?? 'file.xlsx',
        optimizationLevel: optimizationLevelValue,
        onStatusUpdate: (msg) {
          _statusMsg = msg;
          notifyListeners();
        },
      );

      _stats = result.stats;
      _mapData = result.mapData;
      _statusMsg = 'Ready.';
      _errorMsg = null;
    } catch (e) {
      _errorMsg = e.toString().replaceFirst('Exception: ', '');
      _statusMsg = 'Error';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}