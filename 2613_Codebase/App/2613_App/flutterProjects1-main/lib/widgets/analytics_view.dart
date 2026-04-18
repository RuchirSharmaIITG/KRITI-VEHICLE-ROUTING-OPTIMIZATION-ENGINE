import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/map_data.dart';

/// Mirrors VeloraAnalytics.js exactly:
///  • Score header
///  • 4-metric grid (optimized cost, cost saved, time saved, employees)
///  • Stats strip (vehicles, distance, opt time)
///  • Cost bar chart  (baseline vs optimized per vehicle)
///  • Time bar chart  (baseline vs optimized per employee — horizontal scroll)
///  • Constraint compliance bars
///  • Fleet donut + utilization
///  • Violations table
class AnalyticsView extends StatelessWidget {
  final MapData mapData;
  const AnalyticsView({super.key, required this.mapData});

  // Colours matching the web dark theme
  static const Color _bg      = Color(0xFF0C0E14);
  static const Color _card    = Color(0xFF151821);
  static const Color _card2   = Color(0xFF1A1F2E);
  static const Color _border  = Color(0xFF1F2937);
  static const Color _gray    = Color(0xFF9CA3AF);
  static const Color _light   = Color(0xFFD1D5DB);
  static const Color _cyan    = Color(0xFF22D3EE);
  static const Color _emerald = Color(0xFF34D399);
  static const Color _purple  = Color(0xFFA78BFA);
  static const Color _amber   = Color(0xFFFBBF24);
  static const Color _red     = Color(0xFFF87171);
  static const Color _yellow  = Color(0xFFFACC15);

  @override
  Widget build(BuildContext context) {
    final a = mapData.analytics;

    if (!a.hasRealData) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          SizedBox(width: 56, height: 56,
              child: CircularProgressIndicator(color: _cyan, strokeWidth: 3, backgroundColor: _border)),
          SizedBox(height: 20),
          Text('FETCHING ANALYTICS DATA',
              style: TextStyle(color: _gray, fontFamily: 'monospace', letterSpacing: 2, fontSize: 12)),
          SizedBox(height: 8),
          Text('Add a "Baseline" sheet for full cost & time charts',
              style: TextStyle(color: _gray, fontSize: 10)),
        ])),
      );
    }

    final costSaved    = a.totalBaselineCost - a.totalOptimizedCost;
    final costSavedPct = a.totalBaselineCost > 0 ? (costSaved / a.totalBaselineCost * 100) : 0.0;

    return Scaffold(
      backgroundColor: _bg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

          // ── Score header ───────────────────────────────────────────────
          _scoreHeader(a),
          const SizedBox(height: 16),

          // ── 4-metric grid ──────────────────────────────────────────────
          LayoutBuilder(builder: (ctx, c) {
            final cols = c.maxWidth > 600 ? 4 : 2;
            return GridView.count(
              crossAxisCount: cols, crossAxisSpacing: 12, mainAxisSpacing: 12,
              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 1.6,
              children: [
                _metricCard('Optimized Cost',  '₹ ${a.totalOptimizedCost.toStringAsFixed(0)}', Icons.attach_money,    _emerald),
                _metricCard('Cost Saved',      '₹ ${costSaved.toStringAsFixed(0)}',            Icons.trending_down,   _purple,  sub: '(${costSavedPct.toStringAsFixed(1)}%)'),
                _metricCard('Time Saved',      '${a.timeSavingsMin} min',                       Icons.access_time,     _amber),
                _metricCard('Employees',       '${a.totalEmployees}',                           Icons.people_outline,  _cyan),
              ],
            );
          }),
          const SizedBox(height: 12),

          // ── Stats strip ────────────────────────────────────────────────
          Wrap(spacing: 12, runSpacing: 12, children: [
            _smallStat(Icons.directions_car, 'Vehicles Used',    '${a.totalVehiclesUsed}',                    _emerald),
            _smallStat(null,                 'Total Distance',   '${a.totalDistance.toStringAsFixed(1)} km',  _cyan),
            _smallStat(Icons.timer,          'Optimized Time',   '${a.totalOptimizedTime} min',              _cyan),
          ]),
          const SizedBox(height: 24),

          // ── Cost chart ─────────────────────────────────────────────────
          _chartBox('Cost: Baseline vs Optimized (₹)', Icons.trending_down,
              a.perVehicleCostData.isNotEmpty ? _costChart(a)
                  : _noData('No cost data\nAdd a "Baseline" sheet to your Excel file')),
          const SizedBox(height: 24),

          // ── Time chart ─────────────────────────────────────────────────
          _chartBox('Travel Time: Baseline vs Optimized (min)', Icons.access_time,
              a.employeeTimeComparison.isNotEmpty ? _timeChart(a)
                  : _noData('No time data\nAdd a "Baseline" sheet to your Excel file')),
          const SizedBox(height: 24),

          // ── Compliance + Fleet ─────────────────────────────────────────
          LayoutBuilder(builder: (ctx, c) => c.maxWidth > 800
              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _complianceCard(a)), const SizedBox(width: 16), Expanded(child: _fleetCard(a))])
              : Column(children: [_complianceCard(a), const SizedBox(height: 24), _fleetCard(a)])),
          const SizedBox(height: 24),

          // ── Violations ─────────────────────────────────────────────────
          _violationsCard(a),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }

  // ── Score header ──────────────────────────────────────────────────────────
  Widget _scoreHeader(AnalyticsData a) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [_yellow.withOpacity(0.12), _amber.withOpacity(0.06)]),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _yellow.withOpacity(0.3)),
    ),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: _yellow.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.star_rounded, color: _yellow, size: 18)),
      const SizedBox(width: 16),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('OPTIMIZATION SCORE', style: TextStyle(color: _gray, fontSize: 10, fontFamily: 'monospace', letterSpacing: 1)),
        Text(a.totalScore > 0 ? '${a.totalScore}' : 'N/A',
            style: const TextStyle(color: _yellow, fontSize: 32, fontWeight: FontWeight.w900)),
      ]),
      const Spacer(),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('${a.totalVehiclesUsed} routes',  style: const TextStyle(color: _light,  fontSize: 14, fontWeight: FontWeight.bold)),
        Text('${a.totalEmployees} employees',  style: const TextStyle(color: _gray,   fontSize: 12)),
      ]),
    ]),
  );

  // ── Metric card ───────────────────────────────────────────────────────────
  Widget _metricCard(String title, String value, IconData icon, Color c, {String? sub}) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
      Row(children: [
        Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: c, size: 15)),
        const SizedBox(width: 6),
        Expanded(child: Text(title.toUpperCase(), style: const TextStyle(color: _gray, fontSize: 9, fontFamily: 'monospace'), overflow: TextOverflow.ellipsis)),
      ]),
      const Spacer(),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Flexible(child: Text(value, style: TextStyle(color: c, fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
        if (sub != null) ...[const SizedBox(width: 4), Text(sub, style: const TextStyle(color: _gray, fontSize: 10))],
      ]),
    ]),
  );

  Widget _smallStat(IconData? icon, String title, String value, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(8), border: Border.all(color: _border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, color: c, size: 12), const SizedBox(width: 4)],
        Text(title, style: const TextStyle(color: _gray, fontSize: 10, fontFamily: 'monospace')),
      ]),
      const SizedBox(height: 3),
      Text(value, style: TextStyle(color: c, fontSize: 14, fontWeight: FontWeight.bold)),
    ]),
  );

  // ── Chart box wrapper ─────────────────────────────────────────────────────
  Widget _chartBox(String title, IconData icon, Widget child) => Container(
    height: 290,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, color: _cyan, size: 14), const SizedBox(width: 6),
        // ✅ FIX: Expanded prevents title from overflowing
        Expanded(child: Text(title.toUpperCase(), style: const TextStyle(color: _gray, fontSize: 10, fontFamily: 'monospace'), overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 8),
        _dot(_red,  'Baseline'), const SizedBox(width: 8), _dot(_cyan, 'Optimized'),
      ]),
      const SizedBox(height: 16),
      Expanded(child: child),
    ]),
  );

  Widget _dot(Color c, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 7, height: 7, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
    const SizedBox(width: 3),
    Text(label, style: const TextStyle(color: _gray, fontSize: 9)),
  ]);

  Widget _noData(String msg) => Center(child: Text(msg, style: const TextStyle(color: _gray, fontFamily: 'monospace', fontSize: 11), textAlign: TextAlign.center));

  // ── Cost bar chart ────────────────────────────────────────────────────────
  Widget _costChart(AnalyticsData a) {
    final maxY = a.perVehicleCostData.fold(0.0, (m, d) => max(m, max(d.baseline, d.optimized)));
    return BarChart(BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: maxY * 1.4,
      barTouchData: BarTouchData(touchTooltipData: BarTouchTooltipData(
        getTooltipColor: (_) => const Color(0xFF1F2937),
        fitInsideVertically: true, fitInsideHorizontally: true,
        getTooltipItem: (g, gi, rod, ri) => BarTooltipItem(
            '${ri == 0 ? "Base" : "Opt"}\n₹${rod.toY.toStringAsFixed(0)}',
            const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
      )),
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) {
          final i = v.toInt();
          if (i >= 0 && i < a.perVehicleCostData.length) return Padding(padding: const EdgeInsets.only(top: 6), child: Text(a.perVehicleCostData[i].name, style: const TextStyle(color: _gray, fontSize: 9)));
          return const SizedBox.shrink();
        })),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 44, getTitlesWidget: (v, _) => Text('₹${v.toInt()}', style: const TextStyle(color: _gray, fontSize: 9)))),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => const FlLine(color: _border, strokeWidth: 1, dashArray: [3,3])),
      borderData: FlBorderData(show: false),
      barGroups: a.perVehicleCostData.asMap().entries.map((e) => BarChartGroupData(x: e.key, barsSpace: 4, barRods: [
        BarChartRodData(toY: e.value.baseline,  color: _red,  width: 12, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
        BarChartRodData(toY: e.value.optimized, color: _cyan, width: 12, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
      ])).toList(),
    ));
  }

  // ── Time bar chart (horizontal scroll for many employees) ─────────────────
  Widget _timeChart(AnalyticsData a) {
    final maxY = a.employeeTimeComparison.fold(0.0, (m, d) => max(m, max(d.baselineTime, d.optimizedTime)));
    // ✅ FIX: uses max() instead of deprecated MediaQueryData.fromView
    final chartW = max(300.0, a.employeeTimeComparison.length * 60.0);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(width: chartW, child: BarChart(BarChartData(
        alignment: BarChartAlignment.spaceAround, maxY: maxY * 1.4,
        barTouchData: BarTouchData(touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (_) => const Color(0xFF1F2937),
          fitInsideVertically: true, fitInsideHorizontally: true,
          getTooltipItem: (g, gi, rod, ri) => BarTooltipItem('${ri == 0 ? "Base" : "Opt"}\n${rod.toY.toStringAsFixed(1)} min', const TextStyle(color: Colors.white, fontSize: 11)),
        )),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 60, getTitlesWidget: (v, _) {
            final i = v.toInt();
            if (i >= 0 && i < a.employeeTimeComparison.length) return Transform.rotate(angle: -pi / 4, child: Text(a.employeeTimeComparison[i].employeeId, style: const TextStyle(color: _gray, fontSize: 9)));
            return const SizedBox.shrink();
          })),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: const TextStyle(color: _gray, fontSize: 9)))),
          topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => const FlLine(color: _border, strokeWidth: 1, dashArray: [3,3])),
        borderData: FlBorderData(show: false),
        barGroups: a.employeeTimeComparison.asMap().entries.map((e) => BarChartGroupData(x: e.key, barsSpace: 4, barRods: [
          BarChartRodData(toY: e.value.baselineTime,  color: _red,  width: 10, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
          BarChartRodData(toY: e.value.optimizedTime, color: _cyan, width: 10, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
        ])).toList(),
      ))),
    );
  }

  // ── Compliance ────────────────────────────────────────────────────────────
  Widget _complianceCard(AnalyticsData a) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children: [Icon(Icons.security, color: _cyan, size: 16), SizedBox(width: 8), Text('CONSTRAINT COMPLIANCE', style: TextStyle(color: _gray, fontSize: 12, fontFamily: 'monospace'))]),
      const SizedBox(height: 20),
      ...a.compliance.map((c) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(c.label, style: const TextStyle(color: _light, fontSize: 12, fontWeight: FontWeight.bold)),
            Text('${c.percent.toStringAsFixed(1)}%', style: const TextStyle(color: _cyan, fontSize: 12, fontFamily: 'monospace')),
          ]),
          const SizedBox(height: 4),
          RichText(text: TextSpan(text: '${c.current} ', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), children: [TextSpan(text: '/ ${c.max}', style: const TextStyle(color: _gray, fontSize: 12))])),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: (c.percent / 100).clamp(0.0, 1.0),
            backgroundColor: _border,
            color: c.percent >= 90 ? _emerald : c.percent >= 60 ? _amber : _red,
            minHeight: 4, borderRadius: BorderRadius.circular(2),
          ),
        ]),
      )),
    ]),
  );

  // ── Fleet donut ───────────────────────────────────────────────────────────
  Widget _fleetCard(AnalyticsData a) {
    final total     = max(a.totalVehiclesAvailable, 1);
    final used      = a.totalVehiclesUsed;
    final unassigned = max(total - used, 0);
    final util      = (used / total * 100).clamp(0.0, 100.0);
    final avgOcc    = used > 0 ? (a.totalEmployees / used).toStringAsFixed(1) : '0';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_card, _card2], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(12), border: Border.all(color: _border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [Icon(Icons.local_shipping, color: _cyan, size: 16), SizedBox(width: 8), Text('FLEET STATUS', style: TextStyle(color: _gray, fontSize: 12, fontFamily: 'monospace'))]),
        const SizedBox(height: 20),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 110, height: 110, child: PieChart(PieChartData(
            sectionsSpace: 2, centerSpaceRadius: 35, startDegreeOffset: -90,
            sections: [
              PieChartSectionData(color: _amber, value: used.toDouble(), title: '$used', titleStyle: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), radius: 20),
              if (unassigned > 0) PieChartSectionData(color: Color(0xFF4B5563), value: unassigned.toDouble(), title: '$unassigned', titleStyle: const TextStyle(color: Colors.white, fontSize: 10), radius: 20),
            ],
          ))),
          const SizedBox(width: 20),
          Expanded(child: Column(children: [
            _fleetStat('FLEET UTILIZATION', '${util.toStringAsFixed(1)}%', _cyan),
            const SizedBox(height: 8),
            _fleetStat('AVG OCCUPANCY', '$avgOcc pax/veh', _emerald),
          ])),
        ]),
        const SizedBox(height: 16),
        const Text('UNASSIGNED VEHICLES', style: TextStyle(color: _gray, fontSize: 10, fontFamily: 'monospace')),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(minHeight: 36, maxHeight: 90), width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: _border)),
          child: a.unassignedVehicleIds.isNotEmpty
              ? ListView(shrinkWrap: true, children: a.unassignedVehicleIds.map((id) => Text(id, style: const TextStyle(color: _gray, fontSize: 12, fontFamily: 'monospace'))).toList())
              : const Center(child: Text('None', style: TextStyle(color: _gray, fontSize: 12, fontStyle: FontStyle.italic))),
        ),
      ]),
    );
  }

  Widget _fleetStat(String label, String value, Color c) => Container(
    width: double.infinity, padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: _bg.withOpacity(0.8), borderRadius: BorderRadius.circular(10), border: Border.all(color: c.withOpacity(0.2))),
    child: Column(children: [
      Text(label, style: const TextStyle(color: _gray, fontSize: 9, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
      const SizedBox(height: 3),
      Text(value, style: TextStyle(color: c, fontSize: 16, fontWeight: FontWeight.bold)),
    ]),
  );

  // ── Violations table ──────────────────────────────────────────────────────
  Widget _violationsCard(AnalyticsData a) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children: [Icon(Icons.warning_amber_rounded, color: _amber, size: 16), SizedBox(width: 8), Text('CONSTRAINT VIOLATIONS', style: TextStyle(color: _gray, fontSize: 12, fontFamily: 'monospace'))]),
      const SizedBox(height: 16),
      a.violations.isNotEmpty
          ? SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingTextStyle: const TextStyle(color: _gray, fontSize: 11, fontFamily: 'monospace'),
          dataTextStyle:    const TextStyle(color: _light, fontSize: 11),
          dividerThickness: 1, horizontalMargin: 0, columnSpacing: 20,
          columns: const [DataColumn(label: Text('Employee')), DataColumn(label: Text('Type')), DataColumn(label: Text('Expected')), DataColumn(label: Text('Actual'))],
          rows: a.violations.map((v) => DataRow(cells: [
            DataCell(Text(v.employeeId, style: const TextStyle(color: _amber, fontFamily: 'monospace'))),
            DataCell(Text(v.type)),
            DataCell(Text(v.expected, style: const TextStyle(color: _gray))),
            DataCell(Text(v.actual,   style: const TextStyle(color: _gray))),
          ])).toList(),
        ),
      )
          : const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.security, color: _emerald, size: 20), SizedBox(width: 8),
          Text('No constraint violations detected', style: TextStyle(color: _gray, fontFamily: 'monospace')),
        ])),
      ),
    ]),
  );
}
