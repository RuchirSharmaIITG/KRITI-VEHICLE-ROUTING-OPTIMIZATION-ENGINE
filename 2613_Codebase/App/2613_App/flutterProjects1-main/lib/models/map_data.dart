import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

// ─────────────────────────────────────────
//  BASIC MAP PRIMITIVES
// ─────────────────────────────────────────
class MapPoint {
  final double lat;
  final double lng;
  final String? id;
  MapPoint({required this.lat, required this.lng, this.id});
  LatLng toLatLng() => LatLng(lat, lng);
}

class RouteStop {
  final double lat;
  final double lng;
  final int sequence;
  final String type; // 'start' | 'pickup' | 'drop'
  final String id;
  final String time;
  RouteStop({required this.lat, required this.lng, required this.sequence, required this.type, required this.id, required this.time});
  LatLng toLatLng() => LatLng(lat, lng);
}

class VehicleRoute {
  final String vehicleId;
  final Color color;
  final List<LatLng> path;
  final List<RouteStop> stops;
  final String distance;
  final double distanceNum;
  final String duration;
  final int durationMinutes;
  final List<String> passengers;
  final String startTime;
  final String vehicleType;
  final String propulsion;
  final int capacity;
  final int occupancy;

  VehicleRoute({
    required this.vehicleId,
    required this.color,
    required this.path,
    required this.stops,
    required this.distance,
    this.distanceNum = 0,
    required this.duration,
    this.durationMinutes = 0,
    required this.passengers,
    required this.startTime,
    this.vehicleType = 'Normal',
    this.propulsion = 'Electric',
    this.capacity = 4,
    this.occupancy = 0,
  });
}

class Assignment {
  final String employeeId;
  final String vehicleId;
  final String category;
  final String pickupTime;
  final String dropTime;
  Assignment({required this.employeeId, required this.vehicleId, this.category = 'Normal', this.pickupTime = '--:--', this.dropTime = '--:--'});
}

// ─────────────────────────────────────────
//  ANALYTICS  (mirrors VeloraAnalytics.js)
// ─────────────────────────────────────────
class PerVehicleCostData {
  final String name;
  final double baseline;
  final double optimized;
  PerVehicleCostData(this.name, this.baseline, this.optimized);
}

class EmployeeTimeData {
  final String employeeId;
  final double baselineTime;
  final double optimizedTime;
  EmployeeTimeData(this.employeeId, this.baselineTime, this.optimizedTime);
}

class ComplianceItem {
  final String label;
  final int current;
  final int max;
  final double percent;
  ComplianceItem(this.label, this.current, this.max, this.percent);
}

class ViolationItem {
  final String employeeId;
  final String type;
  final String expected;
  final String actual;
  ViolationItem(this.employeeId, this.type, this.expected, this.actual);
}

class AnalyticsData {
  final int totalEmployees;
  final int totalVehiclesUsed;
  final int totalVehiclesAvailable;
  final double totalDistance;
  final int totalScore;
  final double totalOptimizedCost;
  final double totalBaselineCost;
  final int totalOptimizedTime;
  final int totalBaselineTime;
  final double costSavingsPercent;
  final int timeSavingsMin;
  final List<PerVehicleCostData> perVehicleCostData;
  final List<EmployeeTimeData> employeeTimeComparison;
  final List<String> unassignedVehicleIds;
  final List<ViolationItem> violations;
  final List<ComplianceItem> compliance;

  const AnalyticsData({
    this.totalEmployees = 0,
    this.totalVehiclesUsed = 0,
    this.totalVehiclesAvailable = 0,
    this.totalDistance = 0,
    this.totalScore = 0,
    this.totalOptimizedCost = 0,
    this.totalBaselineCost = 0,
    this.totalOptimizedTime = 0,
    this.totalBaselineTime = 0,
    this.costSavingsPercent = 0,
    this.timeSavingsMin = 0,
    this.perVehicleCostData = const [],
    this.employeeTimeComparison = const [],
    this.unassignedVehicleIds = const [],
    this.violations = const [],
    this.compliance = const [],
  });

  bool get hasRealData => totalEmployees > 0 || perVehicleCostData.isNotEmpty;
}

class MapData {
  final List<MapPoint> pickups;
  final List<MapPoint> dropoffs;
  final List<VehicleRoute> routes;
  final List<Assignment> rawAssignments;
  final int totalScore;
  final AnalyticsData analytics;
  final String csvData;         // vehicle routes CSV (velora_optimized_routes.csv)
  final String employeeCsvData; // employee routes CSV (employee_routes.csv) — new in web update

  MapData({
    this.pickups = const [],
    this.dropoffs = const [],
    this.routes = const [],
    this.rawAssignments = const [],
    this.totalScore = 0,
    this.analytics = const AnalyticsData(),
    this.csvData = '',
    this.employeeCsvData = '',
  });

  bool get isEmpty => routes.isEmpty;
}

// ─────────────────────────────────────────
//  SERVICE HELPERS
// ─────────────────────────────────────────
class OptimizationStats {
  final int nodes;
  final int routes;
  final String efficiency;
  final String cost;
  OptimizationStats({required this.nodes, required this.routes, required this.efficiency, this.cost = 'Optimized'});
}

class VehicleDetails {
  final double? lat;
  final double? lng;
  final String availableFrom;
  final String type;
  final String fuel;
  final int capacity;
  final double costPerKm;
  VehicleDetails({this.lat, this.lng, this.availableFrom = '08:00:00', this.type = 'Normal', this.fuel = 'Electric', this.capacity = 4, this.costPerKm = 10.0});
}

class EmployeeLocation {
  final LatLng pickup;
  final LatLng? drop;
  final int priority;
  final String vehiclePref;
  final String sharePref;
  final int earliestPickupMin;
  final int latestDropMin;
  EmployeeLocation({
    required this.pickup,
    this.drop,
    this.priority = 1,
    this.vehiclePref = 'any',
    this.sharePref = 'triple',
    this.earliestPickupMin = 0,
    this.latestDropMin = 1440,
  });
}