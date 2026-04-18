import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../config/constants.dart';
import '../models/map_data.dart';
import '../services/app_state.dart';

/// Mirrors MapBoard.js exactly - Leaflet map with routes, markers, simulation
class MapBoardWidget extends StatefulWidget {
  final List<MapPoint> pickups;
  final List<MapPoint> dropoffs;
  final List<VehicleRoute> routes;
  final int? selectedRouteIndex;
  final int? simulatingVehicleIndex;

  const MapBoardWidget({
    super.key,
    required this.pickups,
    required this.dropoffs,
    required this.routes,
    this.selectedRouteIndex,
    this.simulatingVehicleIndex,
  });

  @override
  State<MapBoardWidget> createState() => _MapBoardWidgetState();
}

class _MapBoardWidgetState extends State<MapBoardWidget> with TickerProviderStateMixin {
  final MapController _mapController = MapController();

  // Simulation state (same as web app's simProgress)
  double _simProgress = 0.0;
  Timer? _simTimer;
  DateTime? _simStartTime;
  String _displayTitle = '';
  String _displayMessage = '';

  // Route animation state
  final Map<int, double> _routeAnimProgress = {};
  final Map<int, Timer?> _routeAnimTimers = {};

  @override
  void didUpdateWidget(MapBoardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle simulation start/stop (same as useEffect in MapBoard.js)
    if (widget.simulatingVehicleIndex != oldWidget.simulatingVehicleIndex) {
      _stopSimulation();
      if (widget.simulatingVehicleIndex != null) {
        _startSimulation();
      }
    }

    // Handle route selection change → fly to bounds
    if (widget.selectedRouteIndex != oldWidget.selectedRouteIndex) {
      _flyToBounds();
    }

    // Handle new routes → animate them
    if (widget.routes.length != oldWidget.routes.length) {
      _startRouteAnimations();
      _flyToBounds();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.routes.isNotEmpty) {
        _startRouteAnimations();
        _flyToBounds();
      }
    });
  }

  void _startRouteAnimations() {
    for (final timer in _routeAnimTimers.values) {
      timer?.cancel();
    }
    _routeAnimTimers.clear();

    for (int i = 0; i < widget.routes.length; i++) {
      _routeAnimProgress[i] = 0.0;
      final timer = Timer.periodic(const Duration(milliseconds: 16), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        setState(() {
          _routeAnimProgress[i] = (_routeAnimProgress[i]! + 0.02).clamp(0.0, 1.0);
          if (_routeAnimProgress[i]! >= 1.0) t.cancel();
        });
      });
      _routeAnimTimers[i] = timer;
    }
  }

  void _flyToBounds() {
    if (!mounted) return;

    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;

      if (widget.selectedRouteIndex != null && widget.routes.isNotEmpty) {
        final route = widget.routes[widget.selectedRouteIndex!];
        if (route.path.isNotEmpty) {
          final bounds = LatLngBounds.fromPoints(route.path);
          _mapController.fitCamera(
            CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60)),
          );
          return;
        }
      }

      // Fit all points
      final allCoords = <LatLng>[];
      for (final p in widget.pickups) allCoords.add(LatLng(p.lat, p.lng));
      for (final d in widget.dropoffs) allCoords.add(LatLng(d.lat, d.lng));
      for (final r in widget.routes) allCoords.addAll(r.path);

      if (allCoords.isNotEmpty) {
        final bounds = LatLngBounds.fromPoints(allCoords);
        _mapController.fitCamera(
          CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
        );
      }
    });
  }

  // --- SIMULATION (mirrors the animation loop in MapBoard.js) ---
  void _startSimulation() {
    _simProgress = 0.0;
    _simStartTime = DateTime.now();
    _simTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted || _simStartTime == null) {
        timer.cancel();
        return;
      }
      final elapsed = DateTime.now().difference(_simStartTime!).inMilliseconds;
      final progress = (elapsed / simulationDurationMs).clamp(0.0, 1.0);
      setState(() {
        _simProgress = progress;
        _updateDisplayStatus();
      });
      if (progress >= 1.0) {
        timer.cancel();
        context.read<AppState>().handleSimulationEnd();
      }
    });
  }

  void _stopSimulation() {
    _simTimer?.cancel();
    _simTimer = null;
    setState(() {
      _simProgress = 0.0;
      _simStartTime = null;
      _displayTitle = '';
      _displayMessage = '';
    });
  }

  // --- STATUS UPDATE (mirrors the hysteresis-based status in MapBoard.js) ---
  void _updateDisplayStatus() {
    if (widget.simulatingVehicleIndex == null || widget.routes.isEmpty) return;
    final route = widget.routes[widget.simulatingVehicleIndex!];
    final title = 'SIMULATING ${route.vehicleId}';

    if (_simProgress >= 1.0) {
      _displayTitle = title;
      _displayMessage = '✅ TRIP COMPLETED';
      return;
    }

    if (route.stops.isEmpty) {
      _displayTitle = title;
      _displayMessage = '⏳ NO STOP DATA';
      return;
    }

    // Simplified status based on progress
    final stopCount = route.stops.length;
    final currentStopIdx = (_simProgress * stopCount).floor().clamp(0, stopCount - 1);
    final currentStop = route.stops[currentStopIdx];

    String message;
    if (currentStop.type == 'start') {
      message = '🏁 AT DEPOT';
    } else if (currentStop.type == 'pickup') {
      message = '📍 PICKING UP ${currentStop.id}';
    } else if (currentStop.type == 'drop') {
      message = '⬇️ DROPPING AT OFFICE';
    } else {
      message = '➡️ EN ROUTE';
    }

    _displayTitle = title;
    _displayMessage = message;
  }

  @override
  void dispose() {
    _simTimer?.cancel();
    for (final timer in _routeAnimTimers.values) {
      timer?.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final center = widget.dropoffs.isNotEmpty
        ? LatLng(widget.dropoffs[0].lat, widget.dropoffs[0].lng)
        : const LatLng(defaultLat, defaultLng);

    return Stack(
      children: [
        // Map
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: defaultZoom,
          ),
          children: [
            // Tile Layer (same OpenStreetMap as web app)
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.velora.control.app',
            ),

            // Routes polylines
            PolylineLayer(
              polylines: _buildPolylines(),
            ),

            // Markers
            MarkerLayer(
              markers: _buildMarkers(),
            ),
          ],
        ),

        // Simulation Status Panel (top-right, same as web)
        if (widget.simulatingVehicleIndex != null && _displayMessage.isNotEmpty)
          Positioned(
            top: 12,
            right: 12,
            child: _buildSimulationPanel(),
          ),

        // Legend (bottom-left, same as web)
        Positioned(
          bottom: 12,
          left: 12,
          child: _buildLegend(),
        ),
      ],
    );
  }

  List<Polyline> _buildPolylines() {
    final polylines = <Polyline>[];
    final isAnySelected = widget.selectedRouteIndex != null;

    for (int i = 0; i < widget.routes.length; i++) {
      final route = widget.routes[i];
      if (route.path.isEmpty) continue;

      final isSelected = widget.selectedRouteIndex == i;
      final isDimmed = isAnySelected && !isSelected;

      // Animated polyline - show partial path based on animation progress
      final progress = _routeAnimProgress[i] ?? 1.0;
      final pointCount = (route.path.length * progress).ceil().clamp(1, route.path.length);
      final visiblePath = route.path.sublist(0, pointCount);

      if (isDimmed) {
        polylines.add(Polyline(
          points: route.path,
          color: const Color(0xFF94A3B8).withValues(alpha: 0.2),
          strokeWidth: 3,
        ));
      } else {
        polylines.add(Polyline(
          points: visiblePath,
          color: route.color.withValues(alpha: 0.9),
          strokeWidth: 5,
        ));
      }
    }

    return polylines;
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];
    final isAnySelected = widget.selectedRouteIndex != null;

    // --- Vehicle car markers (same as TraceRoute car markers in web) ---
    for (int i = 0; i < widget.routes.length; i++) {
      final route = widget.routes[i];
      if (route.path.isEmpty) continue;

      final isDimmed = isAnySelected && widget.selectedRouteIndex != i;
      final isSimulating = widget.simulatingVehicleIndex == i;

      LatLng carPosition;
      if (isSimulating && _simProgress > 0 && route.path.length > 1) {
        // Interpolate position along path
        final idx = (_simProgress * (route.path.length - 1)).floor();
        final t = (_simProgress * (route.path.length - 1)) - idx;
        final safeIdx = idx.clamp(0, route.path.length - 2);
        carPosition = LatLng(
          route.path[safeIdx].latitude + (route.path[safeIdx + 1].latitude - route.path[safeIdx].latitude) * t,
          route.path[safeIdx].longitude + (route.path[safeIdx + 1].longitude - route.path[safeIdx].longitude) * t,
        );
      } else {
        carPosition = route.path[0];
      }

      markers.add(Marker(
        point: carPosition,
        width: 36,
        height: 36,
        child: Opacity(
          opacity: isDimmed ? 0.2 : 1.0,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4)],
            ),
            child: const Icon(Icons.directions_car, color: Color(0xFF1E293B), size: 22),
          ),
        ),
      ));
    }

    if (widget.selectedRouteIndex == null) {
      // --- OVERVIEW MODE ---
      // Depot markers
      for (int i = 0; i < widget.routes.length; i++) {
        final route = widget.routes[i];
        final depotStop = route.stops.where((s) => s.type == 'start').firstOrNull;
        if (depotStop != null) {
          markers.add(_buildMarkerPin(
            LatLng(depotStop.lat, depotStop.lng),
            const Color(0xFFFBBF24), // gold
            Icons.home_outlined,
            '${route.vehicleId} Depot',
          ));
        }
      }

      // Pickup markers (green)
      for (final p in widget.pickups) {
        markers.add(_buildMarkerPin(
          LatLng(p.lat, p.lng),
          VeloraColors.emerald,
          Icons.person_pin,
          'Employee: ${p.id}',
        ));
      }

      // Dropoff markers (red)
      for (final d in widget.dropoffs) {
        markers.add(_buildMarkerPin(
          LatLng(d.lat, d.lng),
          VeloraColors.red,
          Icons.location_on,
          'Office / Drop',
        ));
      }
    } else {
      // --- SELECTED ROUTE MODE ---
      final activeStops = widget.routes[widget.selectedRouteIndex!].stops;
      for (final stop in activeStops) {
        Color color;
        IconData icon;
        String label;

        switch (stop.type) {
          case 'start':
            color = const Color(0xFFFBBF24);
            icon = Icons.home_outlined;
            label = 'Depot';
          case 'pickup':
            color = VeloraColors.emerald;
            icon = Icons.person_pin;
            label = 'Employee: ${stop.id}';
          case 'drop':
            color = VeloraColors.red;
            icon = Icons.location_on;
            label = 'Drop: ${stop.id}';
          default:
            color = VeloraColors.cyan;
            icon = Icons.place;
            label = stop.id;
        }

        markers.add(_buildMarkerPin(
          LatLng(stop.lat, stop.lng),
          color,
          icon,
          label,
        ));
      }
    }

    return markers;
  }

  Marker _buildMarkerPin(LatLng point, Color color, IconData icon, String label) {
    return Marker(
      point: point,
      width: 32,
      height: 40,
      child: GestureDetector(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(label),
              duration: const Duration(seconds: 2),
              backgroundColor: VeloraColors.surfaceLight,
            ),
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 6),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 16),
            ),
            // Pin stem
            Container(
              width: 2,
              height: 6,
              color: color,
            ),
          ],
        ),
      ),
    );
  }

  /// Cyberpunk simulation status panel (same as web app's top-right panel)
  Widget _buildSimulationPanel() {
    return Container(
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 280),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: VeloraColors.cyan),
        boxShadow: [
          BoxShadow(color: VeloraColors.cyan.withValues(alpha: 0.5), blurRadius: 20),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('🌐', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 6),
                  Text(
                    _displayTitle,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: VeloraColors.cyan, letterSpacing: 1, fontFamily: 'monospace'),
                  ),
                ],
              ),
              Row(
                children: [
                  const Text('➡️', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 4),
                  Text(
                    'ACTIVE',
                    style: TextStyle(fontSize: 9, color: VeloraColors.cyan.withValues(alpha: 0.8), letterSpacing: 1, fontFamily: 'monospace'),
                  ),
                ],
              ),
            ],
          ),
          const Divider(color: VeloraColors.surfaceLighter, height: 16),
          // Status message
          Row(
            children: [
              const Text('⚡', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _displayMessage,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Progress bar
          Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  VeloraColors.cyan.withValues(alpha: _simProgress),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Legend (same as web app's bottom-left legend)
  Widget _buildLegend() {
    final pathColor = (widget.selectedRouteIndex != null && widget.routes.isNotEmpty)
        ? widget.routes[widget.selectedRouteIndex!].color
        : VeloraColors.cyan;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10)],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'LIVE FEED LEGEND',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), letterSpacing: 0.5),
          ),
          const SizedBox(height: 8),
          _legendItem(VeloraColors.emerald, Icons.person_pin, 'Employee Pickup'),
          _legendItem(VeloraColors.red, Icons.location_on, 'Office / Drop'),
          _legendItem(const Color(0xFFFBBF24), Icons.home_outlined, 'Vehicle Depot'),
          _legendItem(const Color(0xFF1E293B), Icons.directions_car, 'Fleet Vehicle'),
          _legendLine(pathColor, 'Optimal Path'),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF334155))),
        ],
      ),
    );
  }

  Widget _legendLine(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 16, height: 3, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF334155))),
        ],
      ),
    );
  }
}
