import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../config/constants.dart';
import '../models/map_data.dart';
import 'excel_service.dart';
import 'osrm_service.dart';

class ApiService {
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(minutes: 10), // backend can take 5-8 min on large datasets
    sendTimeout:    const Duration(seconds: 120),
  ));

  static Future<({MapData mapData, OptimizationStats stats})> processFile({
    required Uint8List fileBytes,
    required String fileName,
    required int optimizationLevel,
    required Function(String) onStatusUpdate,
  }) async {
    onStatusUpdate('Reading Excel...');

    // ── Parse all sheets ──────────────────────────────────────────────────
    final sheetData = ExcelService.parseExcel(fileBytes);
    final sheetNames = sheetData.keys.toList();

    final empSheet  = ExcelService.findSheet(sheetNames, 'employee') ?? ExcelService.findSheet(sheetNames, 'request');
    final vehSheet  = ExcelService.findSheet(sheetNames, 'vehicle')  ?? ExcelService.findSheet(sheetNames, 'fleet');
    final metaSheet = ExcelService.findSheet(sheetNames, 'metadata') ?? ExcelService.findSheet(sheetNames, 'config');
    final baseSheet = ExcelService.findSheet(sheetNames, 'baseline') ?? ExcelService.findSheet(sheetNames, 'base');

    if (empSheet == null)  throw Exception("Missing 'Employees' sheet.");
    if (vehSheet == null)  throw Exception("Missing 'Vehicles' sheet.");
    if (metaSheet == null) throw Exception("Missing 'Metadata' sheet.");

    final empRows  = sheetData[empSheet]!;
    final vehRows  = sheetData[vehSheet]!;
    final metaRows = sheetData[metaSheet]!;

    final locationMap      = ExcelService.extractEmployeeLocations(empRows);
    final vehicleDetailsMap = ExcelService.extractVehicleDetails(vehRows);
    final totalEmployees   = locationMap.length;
    if (totalEmployees == 0) throw Exception('No valid employee rows found in sheet.');

    // Baseline sheet (optional — enables cost/time charts in Analytics)
    final baselineMap = baseSheet != null
        ? ExcelService.extractBaseline(sheetData[baseSheet]!)
        : <String, Map<String, double>>{};

    // allow_external_maps from metadata
    bool allowExternalMaps = true;
    for (final row in metaRows) {
      final key = (row['key'] ?? row.keys.firstOrNull ?? '').toString().trim();
      final val = (row['value'] ?? '').toString().trim();
      if (key == 'allow_external_maps') {
        allowExternalMaps = val.toLowerCase() == 'true';
        break;
      }
    }

    // ── Build form data ───────────────────────────────────────────────────
    onStatusUpdate('Sending to backend...');

    final formData = FormData();
    formData.files.add(MapEntry('employees',
        MultipartFile.fromBytes(utf8.encode(ExcelService.sheetToCSV(empRows)),
            filename: 'employees.csv', contentType: DioMediaType('text', 'csv'))));
    formData.files.add(MapEntry('vehicles',
        MultipartFile.fromBytes(utf8.encode(ExcelService.sheetToCSV(vehRows)),
            filename: 'vehicles.csv', contentType: DioMediaType('text', 'csv'))));
    formData.files.add(MapEntry('metadata',
        MultipartFile.fromBytes(utf8.encode(ExcelService.sheetToCSV(metaRows)),
            filename: 'metadata.csv', contentType: DioMediaType('text', 'csv'))));
    if (baseSheet != null) {
      formData.files.add(MapEntry('basedata', // renamed from 'baseline' in web update
          MultipartFile.fromBytes(utf8.encode(ExcelService.sheetToCSV(sheetData[baseSheet]!)),
              filename: 'baseline.csv', contentType: DioMediaType('text', 'csv'))));
    }

    // ✅ FIX 1: Send optimizationLevel field (backend requires this)
    formData.fields.add(MapEntry('optimizationLevel', optimizationLevel.toString()));

    // ── POST  ──────────────────────────────────────────────────────────────
    // ✅ FIX 2: Do NOT set Content-Type manually — Dio adds boundary automatically
    Response response;
    try {
      response = await _dio.post(
        apiEndpoint,
        data: formData,
        options: Options(validateStatus: (s) => s != null && s < 600),
      );
    } on DioException catch (e) {
      throw Exception('Network error: ${e.response?.data ?? e.message}');
    }

    if (response.statusCode != 200) {
      throw Exception('Server ${response.statusCode}: ${response.data}');
    }

    onStatusUpdate('Parsing results...');

    final result = response.data;

    // ── Extract costSave & timeSave from csv_employee line 0 (new in web update) ──
    // Web: let costSave = result.results.mem.csv_employee.split("\n")[0].split(",")[0]
    double serverCostSave = 0;
    double serverTimeSave = 0;
    final csvEmployee = result['results']?['mem']?['csv_employee']?.toString() ?? '';
    if (csvEmployee.isNotEmpty) {
      final firstLine = csvEmployee.split('\n').first.trim();
      final parts = firstLine.split(',');
      serverCostSave = double.tryParse(parts.isNotEmpty ? parts[0].trim() : '') ?? 0;
      serverTimeSave = double.tryParse(parts.length > 1 ? parts[1].trim() : '') ?? 0;
      debugPrint('💰 Server costSave=$serverCostSave  timeSave=$serverTimeSave');
    }

    // ── Also store employee CSV for second download ────────────────────────
    String employeeCsvData = '';
    if (csvEmployee.isNotEmpty) {
      // Skip first line (score line), rest is the employee routes CSV
      final empLines = csvEmployee.split('\n');
      if (empLines.length > 1) employeeCsvData = empLines.skip(1).join('\n');
    }

    // ── Pick best solver (mirrors ControlPanel.js priority: mem > ALNS > GOD > HD > BAC) ──
    String rawCsv = '';
    for (final solver in ['mem', 'ALNS', 'GOD', 'HD', 'BAC']) {
      final csv = result['results']?[solver]?['csv_vehicle'];
      if (csv != null && csv.toString().trim().isNotEmpty) {
        rawCsv = csv.toString();
        debugPrint('✅ Using solver: $solver');
        break;
      }
    }
    if (rawCsv.isEmpty) throw Exception('All solvers failed — no routing data in response.');

    // ── Parse CSV ─────────────────────────────────────────────────────────
    rawCsv = rawCsv.replaceAll('"', '');
    List<String> lines = rawCsv.trim().split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).toList();

    // Score line (first line before header row)
    int parsedScore = 0;
    if (lines.isNotEmpty && !lines.first.toLowerCase().contains('vehicle_id')) {
      final parts = lines.first.split(',');
      parsedScore = (double.tryParse(parts[0].trim()) ?? 0).toInt();
      lines.removeAt(0);
    }

    final headerIdx = lines.indexWhere((l) =>
    l.toLowerCase().contains('vehicle_id') || l.toLowerCase().contains('employee_id'));
    if (headerIdx == -1) throw Exception('Cannot find CSV headers in backend response.');

    final cleanCsv  = lines.skip(headerIdx).join('\n');
    final assignments = ExcelService.parseServerCSV(cleanCsv);
    if (assignments.isEmpty) throw Exception('No valid assignment rows found in response.');

    // ── Case-insensitive employee lookup ──────────────────────────────────
    final superEmpMap = <String, EmployeeLocation>{};
    for (final e in locationMap.entries) {
      final k = e.key.trim().toLowerCase();
      superEmpMap[k] = e.value;
      final stripped = k.replaceAll(RegExp(r'^[a-z0]+'), '');
      if (stripped.isNotEmpty) superEmpMap[stripped] = e.value;
    }

    // ── Group stops by vehicle ────────────────────────────────────────────
    final vehicleGroups = <String, List<Map<String, dynamic>>>{};
    final vehicleInfo   = <String, VehicleDetails>{};

    for (final row in assignments) {
      final vId = (row['vehicle_id'] ?? '').trim();
      if (vId.isEmpty) continue;
      vehicleGroups.putIfAbsent(vId, () => []);
      vehicleInfo.putIfAbsent(vId, () => vehicleDetailsMap[vId] ?? VehicleDetails());

      final empRaw     = row['employee_id'] ?? '';
      final empId      = empRaw.trim().toLowerCase();
      final stripped   = empId.replaceAll(RegExp(r'^[a-z0]+'), '');
      final locs       = superEmpMap[empId] ?? superEmpMap[stripped];

      if (locs != null) {
        vehicleGroups[vId]!.add({'type': 'pickup', 'time': row['pickup_time'] ?? '', 'id': empRaw.toUpperCase(), 'lat': locs.pickup.latitude, 'lng': locs.pickup.longitude});
        if (locs.drop != null) {
          final last = vehicleGroups[vId]!.isNotEmpty ? vehicleGroups[vId]!.last : null;
          if (last == null || last['lat'] != locs.drop!.latitude || last['lng'] != locs.drop!.longitude) {
            vehicleGroups[vId]!.add({'type': 'drop', 'time': row['drop_time'] ?? '', 'id': 'OFFICE', 'lat': locs.drop!.latitude, 'lng': locs.drop!.longitude});
          }
        }
      }
    }

    // ── Build routes + fetch OSRM paths ───────────────────────────────────
    onStatusUpdate(allowExternalMaps ? 'Fetching OSRM routes...' : 'Using haversine...');
    final parsedRoutes = <VehicleRoute>[];

    for (final vId in vehicleGroups.keys) {
      var stops = vehicleGroups[vId]!;
      stops.sort((a, b) => (a['time'] as String).compareTo(b['time'] as String));

      final vDet    = vehicleInfo[vId]!;
      final startMin = stops.isNotEmpty ? ExcelService.timeToMinutes(stops.first['time']) : 0;
      final endMin   = stops.isNotEmpty ? ExcelService.timeToMinutes(stops.last['time'])  : 0;
      final durMins  = endMin - startMin;

      if (vDet.lat != null && vDet.lng != null) {
        stops.insert(0, {'type': 'start', 'time': vDet.availableFrom, 'id': 'DEPOT', 'lat': vDet.lat!, 'lng': vDet.lng!});
      }

      final waypoints = stops.map((s) => LatLng(s['lat'] as double, s['lng'] as double)).toList();
      // ✅ FIX: Always compute a non-zero distance.
      // • allowExternalMaps=false → pure Haversine (metadata flag)
      // • allowExternalMaps=true  → OSRM, auto-falls-back to Haversine on timeout/error
      RoadPathResult road;
      if (waypoints.length < 2) {
        road = RoadPathResult(path: waypoints, distance: 0);
      } else if (!allowExternalMaps) {
        road = OsrmService.haversineOnly(waypoints);
      } else {
        road = await OsrmService.fetchRealRoadPath(waypoints);
      }
      debugPrint('🚗 $vId → ${road.distance} km  osrm=${road.usedOsrm}  stops=${waypoints.length}');

      final passengers = stops.where((s) => s['type'] == 'pickup').map((s) => s['id'] as String).toList();

      parsedRoutes.add(VehicleRoute(
        vehicleId:       vId,
        color:           getVehicleColor(parsedRoutes.length),
        path:            road.path,
        stops:           stops.asMap().entries.map((e) => RouteStop(lat: e.value['lat'] as double, lng: e.value['lng'] as double, sequence: e.key, type: e.value['type'] as String, id: e.value['id'] as String, time: e.value['time'] as String)).toList(),
        distance:        road.distance > 0 ? '${road.distance} km' : '0 km',
        distanceNum:     road.distance.toDouble(),
        duration:        ExcelService.minutesToDurationText(durMins),
        durationMinutes: durMins,
        passengers:      passengers,
        startTime:       stops.isNotEmpty ? stops[0]['time'] as String : '08:00',
        vehicleType:     vDet.type,
        propulsion:      vDet.fuel,
        capacity:        vDet.capacity,
        occupancy:       passengers.length,
      ));
    }

    // ── BUILD ANALYTICS (mirrors ControlPanel.js exactly) ─────────────────
    // Employee optimized time map
    final empTimeMap = <String, int>{};
    for (final row in assignments) {
      final empId = (row['employee_id'] ?? '').trim().toLowerCase();
      final pickup = ExcelService.timeToMinutes(row['pickup_time']);
      final drop   = ExcelService.timeToMinutes(row['drop_time']);
      empTimeMap[empId] = drop - pickup;
    }

    double totalDist = 0, totalOptCost = 0, totalBaseCost = 0;
    int totalOptTime = 0, totalBaseTime = 0;
    final perVehicleCost = <PerVehicleCostData>[];

    for (final route in parsedRoutes) {
      totalDist    += route.distanceNum;
      totalOptTime += route.durationMinutes;
      final costPerKm = vehicleDetailsMap[route.vehicleId]?.costPerKm ?? 10.0;
      final optCost   = route.distanceNum * costPerKm;
      totalOptCost   += optCost;

      double vBase = 0, vBaseTime = 0;
      for (final empId in route.passengers) {
        final k = empId.trim().toLowerCase();
        final stripped = k.replaceAll(RegExp(r'^[a-z0]+'), '');
        final base = baselineMap[k] ?? baselineMap[stripped];
        if (base != null) { vBase += base['cost'] ?? 0; vBaseTime += base['time'] ?? 0; }
      }
      totalBaseCost  += vBase;
      totalBaseTime  += vBaseTime.toInt();
      perVehicleCost.add(PerVehicleCostData(route.vehicleId, vBase, double.parse(optCost.toStringAsFixed(1))));
    }

    // Employee time comparison (only when baseline sheet present)
    final empTimeComparison = <EmployeeTimeData>[];
    for (final entry in baselineMap.entries) {
      final stripped = entry.key.replaceAll(RegExp(r'^[a-z0]+'), '');
      final opt = empTimeMap[entry.key] ?? empTimeMap[stripped];
      if (opt != null) {
        empTimeComparison.add(EmployeeTimeData(entry.key.toUpperCase(), entry.value['time'] ?? 0, opt.toDouble()));
      }
    }

    // ── STEP 1: Build per-vehicle pickup/drop event timeline ─────────────
    // Mirrors vehicleEvents in ControlPanel.js exactly
    final vehicleEvents = <String, List<Map<String, int>>>{};
    for (final route in parsedRoutes) {
      final events = <Map<String, int>>[];
      for (final stop in route.stops) {
        if (stop.type == 'pickup') events.add({'time': ExcelService.timeToMinutes(stop.time), 'delta': 1});
        if (stop.type == 'drop')   events.add({'time': ExcelService.timeToMinutes(stop.time), 'delta': -1});
      }
      events.sort((a, b) => a['time']!.compareTo(b['time']!));
      vehicleEvents[route.vehicleId] = events;
    }

    // ── STEP 2: For each employee, compute max co-occupancy during THEIR window ──
    // Mirrors employeeMaxOccupancy in ControlPanel.js exactly
    // This is what the web uses for sharing preference — NOT total vehicle occupancy
    final employeeMaxOccupancy = <String, int>{};
    for (final row in assignments) {
      final empId   = (row['employee_id'] ?? '').trim().toLowerCase();
      final stripped = empId.replaceAll(RegExp(r'^[a-z0]+'), '');
      final vehicleId = row['vehicle_id'] ?? '';
      final events = vehicleEvents[vehicleId];
      if (events == null) continue;

      final pickupMin = ExcelService.timeToMinutes(row['pickup_time']);
      final dropMin   = ExcelService.timeToMinutes(row['drop_time']);

      // Count occupancy before this employee's pickup
      int occ = 0;
      for (final e in events) {
        if (e['time']! < pickupMin) { occ += e['delta']!; } else { break; }
      }
      // Track max occupancy during this employee's window
      int maxOcc = occ;
      for (final e in events) {
        if (e['time']! >= pickupMin && e['time']! <= dropMin) {
          occ += e['delta']!;
          if (occ > maxOcc) maxOcc = occ;
        }
        if (e['time']! > dropMin) break;
      }
      employeeMaxOccupancy[empId] = maxOcc;
      if (stripped.isNotEmpty) employeeMaxOccupancy[stripped] = maxOcc;
    }

    // ── STEP 3: Compliance checks using correct per-employee occupancy ────
    int vehPrefOk = 0, shareOk = 0, timeOk = 0;
    final violations = <ViolationItem>[];

    for (final row in assignments) {
      final empRaw   = row['employee_id'] ?? '';
      final empId    = empRaw.trim().toLowerCase();
      final stripped = empId.replaceAll(RegExp(r'^[a-z0]+'), '');
      final empLoc   = superEmpMap[empId] ?? superEmpMap[stripped];
      if (empLoc == null) continue;

      final vehicle = parsedRoutes.firstWhere((r) => r.vehicleId == row['vehicle_id'], orElse: () => parsedRoutes.first);
      final vType   = vehicle.vehicleType.toLowerCase();
      final pref    = empLoc.vehiclePref.toLowerCase();

      // Vehicle preference
      final vOk = pref == 'any' || pref == 'normal' || (pref == 'premium' && vType == 'premium');
      if (vOk) { vehPrefOk++; } else { violations.add(ViolationItem(empRaw.toUpperCase(), 'Vehicle Preference', pref, vType)); }

      // Sharing preference — use per-employee max occupancy (matches web exactly)
      final sp     = empLoc.sharePref.toLowerCase();
      final maxOcc = employeeMaxOccupancy[empId] ?? employeeMaxOccupancy[stripped] ?? vehicle.occupancy;
      final sOk    = (sp == 'single' && maxOcc <= 1) || (sp == 'double' && maxOcc <= 2) || (sp == 'triple' && maxOcc <= 3) || sp == 'any';
      if (sOk) { shareOk++; } else { violations.add(ViolationItem(empRaw.toUpperCase(), 'Sharing Preference', sp, '$maxOcc pax (max during trip)')); }

      // Time windows
      final pickMin = ExcelService.timeToMinutes(row['pickup_time']);
      final dropMin = ExcelService.timeToMinutes(row['drop_time']);
      final tOk = pickMin >= empLoc.earliestPickupMin && dropMin <= empLoc.latestDropMin;
      if (tOk) { timeOk++; } else { violations.add(ViolationItem(empRaw.toUpperCase(), 'Time Window', '${_minToTime(empLoc.earliestPickupMin)}–${_minToTime(empLoc.latestDropMin)}', '${row['pickup_time']}–${row['drop_time']}')); }
    }

    final assignedIds  = parsedRoutes.map((r) => r.vehicleId).toSet();
    final unassigned   = vehicleDetailsMap.keys.where((id) => !assignedIds.contains(id)).toList();
    final total        = max(totalEmployees, 1);

    final analytics = AnalyticsData(
      totalEmployees:       totalEmployees,
      totalVehiclesUsed:    parsedRoutes.where((r) => r.occupancy > 0).length,
      totalVehiclesAvailable: vehicleDetailsMap.isNotEmpty ? vehicleDetailsMap.length : parsedRoutes.length,
      totalDistance:        totalDist,
      totalScore:           parsedScore,
      totalOptimizedCost:   totalOptCost,
      totalBaselineCost:    totalBaseCost,
      totalOptimizedTime:   totalOptTime,
      totalBaselineTime:    totalBaseTime,
      costSavingsPercent:   serverCostSave != 0 ? serverCostSave : (totalBaseCost > 0 ? ((totalBaseCost - totalOptCost) / totalBaseCost * 100) : 0),
      timeSavingsMin:       serverTimeSave != 0 ? serverTimeSave.toInt() : (totalBaseTime - totalOptTime),
      perVehicleCostData:   perVehicleCost,
      employeeTimeComparison: empTimeComparison,
      unassignedVehicleIds: unassigned,
      violations:           violations,
      compliance: [
        ComplianceItem('Vehicle Preference', vehPrefOk, total, vehPrefOk / total * 100),
        ComplianceItem('Sharing Preference', shareOk,   total, shareOk   / total * 100),
        ComplianceItem('Time Windows',       timeOk,    total, timeOk    / total * 100),
      ],
    );

    // ── Collect map points ────────────────────────────────────────────────
    final pickupsWithId = <MapPoint>[];
    final dropSet       = <String>{};
    final dropoffs      = <MapPoint>[];
    for (final e in locationMap.entries) {
      pickupsWithId.add(MapPoint(lat: e.value.pickup.latitude, lng: e.value.pickup.longitude, id: e.key));
      if (e.value.drop != null) {
        final key = '${e.value.drop!.latitude},${e.value.drop!.longitude}';
        if (dropSet.add(key)) dropoffs.add(MapPoint(lat: e.value.drop!.latitude, lng: e.value.drop!.longitude));
      }
    }

    final stats = OptimizationStats(
      nodes:      totalEmployees,
      routes:     parsedRoutes.length,
      efficiency: '${totalDist.toStringAsFixed(1)} km Total',
      cost:       '₹${totalOptCost.toStringAsFixed(1)}',
    );

    final mapData = MapData(
      pickups:        pickupsWithId,
      dropoffs:       dropoffs,
      routes:         parsedRoutes,
      rawAssignments: assignments.map((row) => Assignment(
        employeeId: (row['employee_id'] ?? 'N/A').toUpperCase(),
        vehicleId:  row['vehicle_id']  ?? 'N/A',
        category:   row['category']    ?? 'Normal',
        pickupTime: row['pickup_time'] ?? '--:--',
        dropTime:   row['drop_time']   ?? '--:--',
      )).toList(),
      totalScore: parsedScore,
      analytics:  analytics,
      csvData:    cleanCsv,          // vehicle routes CSV
      employeeCsvData: employeeCsvData, // employee routes CSV (new)
    );

    return (mapData: mapData, stats: stats);
  }

  static String _minToTime(int mins) =>
      '${(mins ~/ 60).toString().padLeft(2,'0')}:${(mins % 60).toString().padLeft(2,'0')}';
}