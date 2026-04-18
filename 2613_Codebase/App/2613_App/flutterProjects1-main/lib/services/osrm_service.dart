import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../config/constants.dart';

/// Result of an OSRM route query
class RoadPathResult {
  final List<LatLng> path;
  final double distance; // in km
  final bool usedOsrm;  // true = real road, false = haversine fallback

  RoadPathResult({required this.path, required this.distance, this.usedOsrm = false});
}

/// Service for fetching real road paths from OSRM
/// Mirrors fetchRealRoadPath in ControlPanel.js exactly
/// ✅ FIX: Haversine fallback when OSRM is unavailable (network issue / timeout)
class OsrmService {

  /// Haversine distance between two points in km
  /// Same as haversineDistance in ControlPanel.js
  static double haversineDistance(LatLng a, LatLng b) {
    const R = 6371.0;
    final dLat = (b.latitude  - a.latitude)  * pi / 180;
    final dLon = (b.longitude - a.longitude) * pi / 180;
    final sinDLat = sin(dLat / 2);
    final sinDLon = sin(dLon / 2);
    final h = sinDLat * sinDLat +
        cos(a.latitude * pi / 180) * cos(b.latitude * pi / 180) * sinDLon * sinDLon;
    return R * 2 * atan2(sqrt(h), sqrt(1 - h));
  }

  /// Total haversine distance along a polyline
  static double computeHaversineDistance(List<LatLng> waypoints) {
    double total = 0;
    for (int i = 1; i < waypoints.length; i++) {
      total += haversineDistance(waypoints[i - 1], waypoints[i]);
    }
    return total;
  }

  /// Fetch real road path. Falls back to Haversine if OSRM fails.
  static Future<RoadPathResult> fetchRealRoadPath(List<LatLng> waypoints) async {
    if (waypoints.length < 2) {
      return RoadPathResult(path: waypoints, distance: 0);
    }

    // Build coordinate string: lng,lat;lng,lat;...  (OSRM uses lng,lat order)
    final coordString = waypoints.map((p) => '${p.longitude},${p.latitude}').join(';');

    try {
      final url = '$osrmBaseUrl/$coordString?overview=full&geometries=geojson&continue_straight=true';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 'Ok' && data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];
          final coordinates = route['geometry']['coordinates'] as List;
          final path = coordinates.map<LatLng>((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList();
          final distKm = route['distance'] / 1000.0;
          return RoadPathResult(
            path: path,
            distance: double.parse(distKm.toStringAsFixed(1)),
            usedOsrm: true,
          );
        }
      }
    } catch (e) {
      debugPrint('⚠️ OSRM failed, using Haversine fallback: $e');
    }

    // ✅ FALLBACK: Haversine distance (mirrors ControlPanel.js forceHaversine logic)
    final haversineDist = computeHaversineDistance(waypoints);
    return RoadPathResult(
      path: waypoints,
      distance: double.parse(haversineDist.toStringAsFixed(1)),
      usedOsrm: false,
    );
  }

  /// Pure haversine (for offline / metadata-disabled mode)
  static RoadPathResult haversineOnly(List<LatLng> waypoints) {
    final dist = computeHaversineDistance(waypoints);
    return RoadPathResult(
      path: waypoints,
      distance: double.parse(dist.toStringAsFixed(1)),
      usedOsrm: false,
    );
  }
}
