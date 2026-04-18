import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../config/constants.dart';
import '../services/app_state.dart';
import '../widgets/animated_globe.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});
  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> with SingleTickerProviderStateMixin {
  late AnimationController _fade;
  late Animation<double>  _fadeAnim;
  late Animation<Offset>  _slideAnim;

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(duration: const Duration(milliseconds: 1200), vsync: this);
    _fadeAnim  = CurvedAnimation(parent: _fade, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _fade, curve: Curves.easeOut));
    _fade.forward();
  }

  @override
  void dispose() { _fade.dispose(); super.dispose(); }

  Future<void> _pickFile(AppState state) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
      withData: true,
    );
    if (result != null && result.files.single.bytes != null) {
      state.setFile(result.files.single.name, result.files.single.bytes!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      backgroundColor: VeloraColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: AnimatedGlobeBackground()),
          Center(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo
                      Container(
                        width: 72, height: 72,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [VeloraColors.cyanDark, VeloraColors.blue], begin: Alignment.topLeft, end: Alignment.bottomRight),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: VeloraColors.cyan.withOpacity(0.4), blurRadius: 30)],
                        ),
                        child: const Center(child: Text('V', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 36))),
                      ),
                      const SizedBox(height: 20),
                      const Text('VELORA', style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, letterSpacing: 10, color: Colors.white)),
                      const SizedBox(height: 8),
                      Text('Fleet Optimization Platform', style: TextStyle(fontSize: 14, color: VeloraColors.cyan.withOpacity(0.8), letterSpacing: 2, fontFamily: 'monospace')),
                      const SizedBox(height: 48),

                      // ── Upload card ─────────────────────────────────────
                      GestureDetector(
                        onTap: () => _pickFile(state),
                        child: Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(maxWidth: 420),
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: VeloraColors.surface.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: state.hasFile ? VeloraColors.emerald.withOpacity(0.5) : VeloraColors.borderCyan,
                              width: 1.5,
                            ),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 30)],
                          ),
                          child: state.hasFile ? _buildFileSelected(state) : _buildFilePrompt(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilePrompt() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 56, height: 56,
        decoration: BoxDecoration(color: VeloraColors.cyan.withOpacity(0.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: VeloraColors.borderCyan, width: 1.5)),
        child: const Icon(Icons.upload_file_outlined, color: VeloraColors.cyan, size: 28),
      ),
      const SizedBox(height: 16),
      const Text('Upload Excel File', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
      const SizedBox(height: 6),
      Text('Drag & drop or tap to browse\n.xlsx files with Employee, Vehicle & Metadata sheets',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: VeloraColors.textMuted, height: 1.6)),
    ],
  );

  Widget _buildFileSelected(AppState state) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.verified_rounded, color: VeloraColors.emerald, size: 52,
          shadows: [Shadow(color: VeloraColors.emerald.withOpacity(0.5), blurRadius: 20)]),
      const SizedBox(height: 14),
      Text(state.fileName ?? 'File',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
          textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
      const SizedBox(height: 20),

      // ── INITIALIZE MAP button ────────────────────────────────────────
      SizedBox(
        width: double.infinity,
        child: GestureDetector(
          onTap: state.isProcessing ? null : () => state.handleProceed(),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [VeloraColors.cyanDark, VeloraColors.blue]),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: VeloraColors.cyan.withOpacity(0.4), blurRadius: 24)],
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (state.isProcessing)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              else
                const Text('INITIALIZE MAP', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward, color: Colors.white, size: 16),
            ]),
          ),
        ),
      ),
      const SizedBox(height: 16),

      // ── Optimization level selector (NEW — mirrors web <select>) ──────
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: VeloraColors.background.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: VeloraColors.surfaceLighter),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: state.optimizationLevel,
            isExpanded: true,
            dropdownColor: VeloraColors.surfaceLight,
            icon: const Icon(Icons.keyboard_arrow_down, color: VeloraColors.cyan, size: 18),
            style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
            onChanged: (val) { if (val != null) state.setOptimizationLevel(val); },
            items: const [
              DropdownMenuItem(value: 'ultra_fast', child: Text('⚡  Ultra Fast - [15s]')),
              DropdownMenuItem(value: 'fast',       child: Text('🚀  Fast - [25s]')),
              DropdownMenuItem(value: 'optimal',    child: Text('🎯  Optimal - [60s]')),
            ],
          ),
        ),
      ),

      const SizedBox(height: 12),
      // Re-upload link
      GestureDetector(
        onTap: () => _pickFile(state),
        child: Text('Change file', style: TextStyle(fontSize: 11, color: VeloraColors.cyan.withOpacity(0.7), decoration: TextDecoration.underline, decorationColor: VeloraColors.cyan.withOpacity(0.4))),
      ),
    ],
  );
}