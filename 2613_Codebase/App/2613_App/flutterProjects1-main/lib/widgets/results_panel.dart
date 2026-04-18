import 'package:flutter/material.dart';
import '../config/constants.dart';
import '../models/map_data.dart';

/// Mirrors ResultsPanel.js exactly
class ResultsPanelWidget extends StatelessWidget {
  final MapData data;
  final int? selectedIndex;
  final Function(int?) onVehicleSelect;
  final Function(int) onSimulateClick;

  const ResultsPanelWidget({
    super.key,
    required this.data,
    this.selectedIndex,
    required this.onVehicleSelect,
    required this.onSimulateClick,
  });

  @override
  Widget build(BuildContext context) {
    if (data.routes.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: VeloraColors.textMuted.withValues(alpha: 0.5), size: 24),
            const SizedBox(height: 8),
            const Text(
              'NO_ACTIVE_VEHICLES',
              style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: VeloraColors.textMuted),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // "All Vehicle Routes" button (same as web)
        GestureDetector(
          onTap: () => onVehicleSelect(null),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: selectedIndex == null ? VeloraColors.cyan.withValues(alpha: 0.2) : VeloraColors.surfaceLight,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: selectedIndex == null ? VeloraColors.cyan.withValues(alpha: 0.5) : VeloraColors.surfaceLighter,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.layers_outlined, size: 12,
                    color: selectedIndex == null ? VeloraColors.cyan : VeloraColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  'All Vehicle Routes',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    color: selectedIndex == null ? VeloraColors.cyan : VeloraColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Fleet count header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Optimized Fleet (${data.routes.length})',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              color: VeloraColors.textMuted,
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Vehicle cards
        ...data.routes.asMap().entries.map((entry) {
          final index = entry.key;
          final route = entry.value;
          return _buildVehicleCard(route, index);
        }),

        const SizedBox(height: 40), // bottom padding
      ],
    );
  }

  Widget _buildVehicleCard(VehicleRoute route, int index) {
    final isSelected = selectedIndex == index;

    return GestureDetector(
      onTap: () => onVehicleSelect(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? VeloraColors.surfaceLight : VeloraColors.surfaceLight.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? VeloraColors.cyan : VeloraColors.surfaceLighter.withValues(alpha: 0.5),
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: VeloraColors.cyan.withValues(alpha: 0.1), blurRadius: 15)]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Vehicle title row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isSelected ? VeloraColors.cyan.withValues(alpha: 0.2) : VeloraColors.surfaceLighter.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(Icons.directions_car, size: 16,
                      color: isSelected ? VeloraColors.cyan : VeloraColors.textSecondary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        route.vehicleId.isNotEmpty ? route.vehicleId : 'Vehicle ${index + 1}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? VeloraColors.cyan : VeloraColors.textPrimary,
                        ),
                      ),
                      const Text(
                        'Active Route',
                        style: TextStyle(fontSize: 9, color: VeloraColors.textMuted, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ),
                // Simulate button (same as web's Play button)
                GestureDetector(
                  onTap: () => onSimulateClick(index),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: VeloraColors.surfaceLighter,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.play_arrow, color: Colors.white, size: 16),
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right, color: VeloraColors.cyan.withValues(alpha: 0.8), size: 16),
                ],
              ],
            ),

            const SizedBox(height: 10),

            // Stats grid (same as web)
            Row(
              children: [
                _statChip(Icons.navigation_outlined, 'Total Dist', route.distance, VeloraColors.emerald),
                const SizedBox(width: 8),
                _statChip(Icons.access_time, 'Total Time', route.duration, const Color(0xFFFB923C)),
              ],
            ),

            const SizedBox(height: 10),

            // Passengers list (same as web)
            Container(
              padding: const EdgeInsets.only(top: 8),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: VeloraColors.surfaceLighter, width: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.people_outline, size: 12, color: VeloraColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        'PASSENGERS (${route.passengers.length})',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                          color: VeloraColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: route.passengers.isNotEmpty
                        ? route.passengers.map((pid) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: VeloraColors.surfaceLighter.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: VeloraColors.surfaceLighter.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          pid,
                          style: const TextStyle(fontSize: 9, color: VeloraColors.textSecondary),
                        ),
                      );
                    }).toList()
                        : [
                      const Text(
                        'No passengers assigned',
                        style: TextStyle(fontSize: 9, color: VeloraColors.textMuted, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statChip(IconData icon, String label, String value, Color iconColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: VeloraColors.surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 12, color: iconColor),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 8, color: VeloraColors.textMuted, letterSpacing: 0.3)),
                  Text(value, style: const TextStyle(fontSize: 11, color: VeloraColors.textPrimary, fontFamily: 'monospace')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
