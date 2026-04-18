import 'package:flutter/material.dart';
import '../config/constants.dart';
import '../models/map_data.dart';

/// Mirrors the Live Fleet Manifest table in page.js dashboard_view
/// Columns: Vehicle ID | Type | Employees Count | Distance | Est. Duration | Propulsion
class FleetTable extends StatelessWidget {
  final List<VehicleRoute> routes;
  const FleetTable({super.key, required this.routes});

  static const _headerStyle = TextStyle(
    fontSize: 10, fontWeight: FontWeight.bold,
    color: VeloraColors.cyan, letterSpacing: 1, fontFamily: 'monospace',
  );

  @override
  Widget build(BuildContext context) {
    if (routes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: VeloraColors.surface.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: VeloraColors.surfaceLighter),
        ),
        child: const Center(
          child: Text('Waiting for optimization data from server...',
              style: TextStyle(color: VeloraColors.textMuted, fontFamily: 'monospace', fontStyle: FontStyle.italic, fontSize: 13)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: VeloraColors.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VeloraColors.surfaceLighter),
      ),
      clipBehavior: Clip.antiAlias,
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
                  SizedBox(width: 90,  child: Text('VEHICLE ID',      style: _headerStyle)),
                  SizedBox(width: 90,  child: Text('TYPE',            style: _headerStyle)),
                  SizedBox(width: 110, child: Text('EMPLOYEES COUNT', style: _headerStyle)),
                  SizedBox(width: 100, child: Text('DISTANCE',        style: _headerStyle)),
                  SizedBox(width: 110, child: Text('EST. DURATION',   style: _headerStyle)),
                  SizedBox(width: 100, child: Text('PROPULSION',      style: _headerStyle)),
                ]),
              ),
              ...routes.map(_buildRow),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(VehicleRoute route) {
    final isPremium = route.vehicleType.toLowerCase().contains('prem');
    final hasData   = route.occupancy > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: VeloraColors.surfaceLighter, width: 0.5)),
      ),
      child: Row(children: [

        // Vehicle ID
        SizedBox(
          width: 90,
          child: Text(route.vehicleId,
              style: const TextStyle(fontSize: 13, fontFamily: 'monospace', color: Colors.white, fontWeight: FontWeight.w600)),
        ),

        // Type badge — purple PREMIUM / gray NORMAL (matches web)
        SizedBox(
          width: 90,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color:  isPremium ? VeloraColors.purple.withOpacity(0.12) : VeloraColors.surfaceLight,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: isPremium ? VeloraColors.purple.withOpacity(0.4) : VeloraColors.surfaceLighter),
            ),
            child: Text(
              isPremium ? 'PREMIUM' : 'NORMAL',
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.8,
                  color: isPremium ? VeloraColors.purple : VeloraColors.textSecondary),
            ),
          ),
        ),

        // Employees Count — cyan circle badge (matches web numbered badge)
        SizedBox(
          width: 110,
          child: hasData
              ? Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: VeloraColors.cyan.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(color: VeloraColors.cyan.withOpacity(0.3)),
            ),
            child: Center(
              child: Text('${route.occupancy}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: VeloraColors.cyan)),
            ),
          )
              : const Text('N/A', style: TextStyle(fontSize: 12, color: VeloraColors.textMuted, fontFamily: 'monospace')),
        ),

        // Distance
        SizedBox(
          width: 100,
          child: Row(children: [
            const Icon(Icons.near_me_outlined, size: 13, color: VeloraColors.cyan),
            const SizedBox(width: 5),
            Text(hasData ? route.distance : 'N/A',
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Colors.white)),
          ]),
        ),

        // Est. Duration
        SizedBox(
          width: 110,
          child: Row(children: [
            const Icon(Icons.access_time_outlined, size: 13, color: VeloraColors.textMuted),
            const SizedBox(width: 5),
            Text(hasData ? route.duration : 'N/A',
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: VeloraColors.textSecondary)),
          ]),
        ),

        // Propulsion
        SizedBox(
          width: 100,
          child: Row(children: [
            const Icon(Icons.local_gas_station_outlined, size: 13, color: VeloraColors.textMuted),
            const SizedBox(width: 5),
            Text(route.propulsion.isNotEmpty ? route.propulsion : 'N/A',
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: VeloraColors.textSecondary)),
          ]),
        ),

      ]),
    );
  }
}
