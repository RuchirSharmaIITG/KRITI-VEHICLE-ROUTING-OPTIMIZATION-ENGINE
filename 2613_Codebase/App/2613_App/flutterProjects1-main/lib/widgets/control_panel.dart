import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/constants.dart';
import '../services/app_state.dart';

/// Mirrors ControlPanel.js — stats panel with Download CSV button (NEW)
class ControlPanelWidget extends StatefulWidget {
  final String? fileName;
  final Uint8List? fileBytes;
  const ControlPanelWidget({super.key, this.fileName, this.fileBytes});

  @override
  State<ControlPanelWidget> createState() => _ControlPanelWidgetState();
}

class _ControlPanelWidgetState extends State<ControlPanelWidget> {
  bool _expanded = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized && widget.fileBytes != null) {
      _initialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<AppState>().handleUploadAndOptimize();
      });
    }
  }

  // ── Download CSVs (mirrors handleDownloadCSV in page.js) ────────────────
  // Web now downloads TWO files:
  //   1. velora_optimized_routes.csv  (vehicle routes)
  //   2. employee_routes.csv          (employee routes — new in web update)
  void _downloadCSV(BuildContext context, AppState state) {
    final csv1 = state.mapData.csvData;
    final csv2 = state.mapData.employeeCsvData;
    if (csv1.isEmpty && csv2.isEmpty) return;

    final hasEmployee = csv2.isNotEmpty;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: VeloraColors.surfaceLight,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Row(children: [
          const Icon(Icons.download_done_rounded, color: VeloraColors.emerald, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            const Text('CSV Ready', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            Text(
                hasEmployee
                    ? 'velora_optimized_routes.csv + employee_routes.csv'
                    : '${state.mapData.rawAssignments.length} rows — velora_optimized_routes.csv',
                style: const TextStyle(color: VeloraColors.textSecondary, fontSize: 11)),
          ])),
        ]),
        action: SnackBarAction(label: 'OK', textColor: VeloraColors.cyan, onPressed: () {}),
      ),
    );
    // NOTE: Wire up share_plus or path_provider here to actually save both files.
    // csv1 → velora_optimized_routes.csv
    // csv2 → employee_routes.csv
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Container(
      decoration: BoxDecoration(
        color: VeloraColors.surface,
        border: Border(bottom: BorderSide(color: VeloraColors.surfaceLighter.withOpacity(0.5))),
      ),
      child: Column(children: [
        // ── Collapsed header ─────────────────────────────────────────────
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              const Icon(Icons.settings, color: VeloraColors.cyan, size: 16),
              const SizedBox(width: 6),
              const Text('Velora Control', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
              const Spacer(),
              // ── Download CSV button ────────────────────────────────────
              if (state.mapData.csvData.isNotEmpty)
                GestureDetector(
                  onTap: () => _downloadCSV(context, state),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: VeloraColors.emerald.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: VeloraColors.emerald.withOpacity(0.4)),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.download_rounded, color: VeloraColors.emerald, size: 12),
                      SizedBox(width: 4),
                      Text('CSV', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: VeloraColors.emerald, letterSpacing: 1)),
                    ]),
                  ),
                ),
              const SizedBox(width: 6),
              if (state.loading)
                const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: VeloraColors.cyan)),
              const SizedBox(width: 6),
              // Status badge — constrained width prevents overflow
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: state.stats != null ? VeloraColors.emerald.withOpacity(0.15) : state.errorMsg != null ? VeloraColors.red.withOpacity(0.15) : VeloraColors.surfaceLight,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: state.stats != null ? VeloraColors.emerald.withOpacity(0.3) : state.errorMsg != null ? VeloraColors.red.withOpacity(0.3) : VeloraColors.surfaceLighter),
                  ),
                  child: Text(
                    state.statusMsg,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, fontFamily: 'monospace',
                        color: state.stats != null ? VeloraColors.emerald : state.errorMsg != null ? VeloraColors.red : VeloraColors.textMuted),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: VeloraColors.textSecondary, size: 20),
            ]),
          ),
        ),

        // ── Expanded content ─────────────────────────────────────────────
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: const SizedBox.shrink(),
          secondChild: _buildExpanded(context, state),
        ),
      ]),
    );
  }

  Widget _buildExpanded(BuildContext context, AppState state) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(children: [
        if (state.errorMsg != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: VeloraColors.red.withOpacity(0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: VeloraColors.red.withOpacity(0.3))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.error_outline, color: VeloraColors.red, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Error', style: TextStyle(color: VeloraColors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 4),
                Text(state.errorMsg!, style: TextStyle(color: VeloraColors.red.withOpacity(0.8), fontSize: 11)),
              ])),
            ]),
          ),

        if (state.stats != null) ...[
          Row(children: [
            _statCard('EMPLOYEES', '${state.stats!.nodes}', Icons.people_outline, VeloraColors.textMuted),
            const SizedBox(width: 8),
            _statCard('VEHICLES', '${state.stats!.routes}', null, VeloraColors.emerald),
          ]),
          const SizedBox(height: 8),
          Container(
            width: double.infinity, padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [VeloraColors.cyan.withOpacity(0.08), VeloraColors.blue.withOpacity(0.08)]),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: VeloraColors.cyan.withOpacity(0.3)),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('TOTAL FLEET DISTANCE', style: TextStyle(color: VeloraColors.cyan.withOpacity(0.8), fontSize: 9, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(state.stats!.efficiency, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
                Text(state.stats!.cost, style: const TextStyle(fontSize: 13, color: VeloraColors.emerald, fontFamily: 'monospace')),
              ]),
              const Icon(Icons.bolt, color: VeloraColors.cyan, size: 24),
            ]),
          ),
          // ── Optimization level display ──────────────────────────────
          const SizedBox(height: 8),
          Container(
            width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: VeloraColors.surfaceLight, borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              const Icon(Icons.speed, color: VeloraColors.cyan, size: 14),
              const SizedBox(width: 8),
              Text('MODE: ${state.optimizationLevel.toUpperCase().replaceAll('_', ' ')}', style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: VeloraColors.cyan)),
              const Spacer(),
              Text('${state.optimizationLevelValue}s', style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: VeloraColors.textMuted)),
            ]),
          ),
        ] else if (!state.loading)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(border: Border.all(color: VeloraColors.surfaceLighter, width: 2), borderRadius: BorderRadius.circular(8)),
            child: Center(child: Column(children: [
              Icon(Icons.table_chart_outlined, color: VeloraColors.textMuted.withOpacity(0.5), size: 24),
              const SizedBox(height: 8),
              Text(state.statusMsg, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: VeloraColors.textMuted)),
            ])),
          ),

        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _btn('RETRY', Icons.refresh, state.loading ? null : () => state.handleUploadAndOptimize(), VeloraColors.surfaceLight, VeloraColors.textSecondary)),
          const SizedBox(width: 8),
          Expanded(child: _btn('UPLOAD EXCEL', Icons.upload_file, () => state.resetApp(), VeloraColors.cyanDark, Colors.white)),
        ]),
      ]),
    );
  }

  Widget _statCard(String label, String value, IconData? icon, Color c) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: VeloraColors.surfaceLight, borderRadius: BorderRadius.circular(8), border: Border.all(color: VeloraColors.surfaceLighter)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: VeloraColors.textSecondary, fontSize: 9, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Row(children: [
          if (icon != null) ...[Icon(icon, color: VeloraColors.textMuted, size: 16), const SizedBox(width: 6)],
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: c)),
        ]),
      ]),
    ),
  );

  Widget _btn(String label, IconData icon, VoidCallback? onTap, Color bg, Color fg) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6), border: Border.all(color: VeloraColors.surfaceLighter)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: fg, size: 14), const SizedBox(width: 6),
            Text(label, style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.bold)),
          ]),
        ),
      );
}