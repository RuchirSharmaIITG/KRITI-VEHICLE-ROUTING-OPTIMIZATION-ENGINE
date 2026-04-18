import 'package:flutter/material.dart';
import '../config/constants.dart';
import '../models/map_data.dart';

/// Dashboard employee table — overflow fixed, drop time + category added
class EmployeeTable extends StatelessWidget {
  final List<Assignment> assignments;
  const EmployeeTable({super.key, required this.assignments});

  String _duration(String start, String end) {
    if (start.isEmpty || end.isEmpty || start == '--:--' || end == '--:--') return 'N/A';
    final s = start.split(':').map((p) => int.tryParse(p) ?? 0).toList();
    final e = end.split(':').map((p) => int.tryParse(p) ?? 0).toList();
    var diff = (e[0] * 60 + (e.length > 1 ? e[1] : 0)) - (s[0] * 60 + (s.length > 1 ? s[1] : 0));
    if (diff < 0) diff += 24 * 60;
    final h = diff ~/ 60; final m = diff % 60;
    // Shortened format "1h 8m" never overflows
    return h > 0 ? '${h}h ${m}m' : '$m min';
  }

  static const _headerStyle = TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: VeloraColors.emerald, letterSpacing: 0.8, fontFamily: 'monospace');

  @override
  Widget build(BuildContext context) {
    if (assignments.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: VeloraColors.surface.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: VeloraColors.surfaceLighter),
        ),
        child: const Center(child: Text('Waiting for assignment data...', style: TextStyle(color: VeloraColors.textMuted, fontFamily: 'monospace', fontStyle: FontStyle.italic, fontSize: 13))),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: VeloraColors.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VeloraColors.surfaceLighter),
      ),
      clipBehavior: Clip.antiAlias,
      // ✅ FIX: horizontal scroll so duration never overflows screen
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: IntrinsicWidth(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: VeloraColors.surfaceLight.withOpacity(0.5),
                  border: const Border(bottom: BorderSide(color: VeloraColors.surfaceLighter)),
                ),
                child: const Row(children: [
                  SizedBox(width: 76, child: Text('EMPLOYEE', style: _headerStyle)),
                  SizedBox(width: 80, child: Text('VEHICLE',  style: _headerStyle)),
                  SizedBox(width: 62, child: Text('PICKUP',   style: _headerStyle)),
                  SizedBox(width: 62, child: Text('DROP',     style: _headerStyle)),
                  SizedBox(width: 70, child: Text('DURATION', style: _headerStyle)),
                  SizedBox(width: 76, child: Text('CATEGORY', style: _headerStyle)),
                ]),
              ),
              // Rows
              ...assignments.map(_buildRow),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(Assignment a) {
    final isPremium = a.category.toLowerCase() == 'premium';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: VeloraColors.surfaceLighter, width: 0.5))),
      child: Row(children: [
        // Employee ID
        SizedBox(width: 76, child: Text(a.employeeId, style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: VeloraColors.emerald, fontWeight: FontWeight.bold))),
        // Vehicle
        SizedBox(width: 80, child: Row(children: [
          const Icon(Icons.directions_car, size: 12, color: VeloraColors.textMuted),
          const SizedBox(width: 4),
          Flexible(child: Text(a.vehicleId, style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Colors.white), overflow: TextOverflow.ellipsis)),
        ])),
        // Pickup time
        SizedBox(width: 62, child: Row(children: [
          const Icon(Icons.location_on, size: 10, color: VeloraColors.emerald),
          const SizedBox(width: 3),
          Text(a.pickupTime, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: VeloraColors.textSecondary)),
        ])),
        // Drop time (NEW)
        SizedBox(width: 62, child: Row(children: [
          const Icon(Icons.flag_outlined, size: 10, color: VeloraColors.cyan),
          const SizedBox(width: 3),
          Text(a.dropTime, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: VeloraColors.textSecondary)),
        ])),
        // Duration (was overflowing before — now has fixed width inside scroll)
        SizedBox(width: 70, child: Row(children: [
          const Icon(Icons.timer_outlined, size: 10, color: VeloraColors.cyan),
          const SizedBox(width: 3),
          Text(_duration(a.pickupTime, a.dropTime), style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: VeloraColors.textSecondary)),
        ])),
        // Category badge (NEW — matches web)
        SizedBox(width: 76, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isPremium ? VeloraColors.yellow.withOpacity(0.14) : VeloraColors.emerald.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: isPremium ? VeloraColors.yellow.withOpacity(0.4) : VeloraColors.emerald.withOpacity(0.3)),
          ),
          child: Text(isPremium ? 'PREMIUM' : 'NORMAL', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, fontFamily: 'monospace', color: isPremium ? VeloraColors.yellow : VeloraColors.emerald)),
        )),
      ]),
    );
  }
}
