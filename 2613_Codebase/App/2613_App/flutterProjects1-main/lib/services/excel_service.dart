import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:csv/csv.dart';
import 'package:latlong2/latlong.dart';
import '../models/map_data.dart';

/// Mirrors ControlPanel.js Excel parsing logic exactly
class ExcelService {

  // ── Time helpers ──────────────────────────────────────────────────────────

  static String excelTimeToHHMMSS(dynamic serial) {
    if (serial is String) return serial;
    if (serial is! num) return '08:00:00';
    final totalSeconds = (serial * 24 * 3600).floor();
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    return '${h.toString().padLeft(2,'0')}:${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}';
  }

  static int timeToMinutes(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return 0;
    final parts = timeStr.split(':').map((p) => int.tryParse(p) ?? 0).toList();
    return (parts[0] * 60) + (parts.length > 1 ? parts[1] : 0);
  }

  static String minutesToDurationText(int totalMins) {
    if (totalMins <= 0) return '0 min';
    final h = totalMins ~/ 60;
    final m = totalMins % 60;
    if (h > 0) return '${h}h ${m}m';
    return '$m min';
  }

  // ── Sheet helpers ─────────────────────────────────────────────────────────

  static String? findSheet(List<String> names, String target) {
    return names.cast<String?>().firstWhere(
          (n) => n != null && n.toLowerCase().contains(target.toLowerCase()),
      orElse: () => null,
    );
  }

  static dynamic findValue(Map<String, dynamic> row, List<String> aliases) {
    final keys = row.keys.toList();
    for (final alias in aliases) {
      final clean = alias.toLowerCase().replaceAll(RegExp(r'[\s_]'), '');
      final key = keys.cast<String?>().firstWhere(
            (k) => k != null && k.toLowerCase().replaceAll(RegExp(r'[\s_]'), '') == clean,
        orElse: () => null,
      );
      if (key != null && row[key] != null) return row[key];
    }
    return null;
  }

  // ── Parse entire Excel file ───────────────────────────────────────────────

  static Map<String, List<Map<String, dynamic>>> parseExcel(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    final result = <String, List<Map<String, dynamic>>>{};

    for (final sheetName in excel.tables.keys) {
      final sheet = excel.tables[sheetName]!;
      if (sheet.rows.isEmpty) continue;

      final headers = sheet.rows[0]
          .map((cell) => cell?.value?.toString().trim() ?? '')
          .toList();

      final rows = <Map<String, dynamic>>[];
      for (int i = 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];
        final map = <String, dynamic>{};
        for (int j = 0; j < headers.length; j++) {
          final val = j < row.length ? row[j]?.value : null;
          map[headers[j]] = val;
        }
        if (map.values.any((v) => v != null && v.toString().trim().isNotEmpty)) {
          rows.add(map);
        }
      }
      result[sheetName] = rows;
    }
    return result;
  }

  // ── Sheet → CSV string (for backend upload) ───────────────────────────────

  static String sheetToCSV(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return '';
    final headers = rows.first.keys.toList();
    final csvRows = <List<dynamic>>[headers];
    for (final row in rows) {
      csvRows.add(headers.map((h) => row[h]?.toString() ?? '').toList());
    }
    return const ListToCsvConverter().convert(csvRows);
  }

  // ── Employee locations + all pref fields ─────────────────────────────────

  static Map<String, EmployeeLocation> extractEmployeeLocations(
      List<Map<String, dynamic>> empRows) {
    final map = <String, EmployeeLocation>{};

    for (final row in empRows) {
      final id = (findValue(row, ['id', 'employee', 'employee_id']) ??
          row['employee_id'] ?? row['id'] ?? row['ID'])
          ?.toString();

      final pLat = _parseDouble(findValue(row, ['pickup_lat', 'pickuplatitude', 'lat', 'latitude']) ?? row['pickup_lat'] ?? row['lat']);
      final pLng = _parseDouble(findValue(row, ['pickup_lng', 'pickuplongitude', 'lng', 'longitude']) ?? row['pickup_lng'] ?? row['lng']);
      final dLat = _parseDouble(findValue(row, ['drop_lat', 'droplatitude', 'officelat']) ?? row['drop_lat'] ?? row['drop_latitude']);
      final dLng = _parseDouble(findValue(row, ['drop_lng', 'droplongitude', 'officelng']) ?? row['drop_lng'] ?? row['drop_longitude']);

      if (id == null || pLat == null || pLng == null) continue;

      // Priority & preferences (needed for compliance check)
      final priority = int.tryParse((findValue(row, ['priority']) ?? row['priority'] ?? 1).toString()) ?? 1;
      final vehPref = (findValue(row, ['vehicle_preference', 'vehicle_type', 'pref']) ?? row['vehicle_preference'] ?? 'any').toString().toLowerCase();
      final sharePref = (findValue(row, ['sharing_preference', 'sharing']) ?? row['sharing_preference'] ?? 'triple').toString().toLowerCase();

      // Time windows
      dynamic earliest = findValue(row, ['earliest_pickup', 'pickup_start', 'start_time', 'ready_time']) ?? row['earliest_pickup'];
      dynamic latest   = findValue(row, ['latest_drop', 'drop_end', 'end_time', 'due_time']) ?? row['latest_drop'];
      if (earliest is num) earliest = excelTimeToHHMMSS(earliest);
      if (latest   is num) latest   = excelTimeToHHMMSS(latest);

      map[id] = EmployeeLocation(
        pickup: LatLng(pLat, pLng),
        drop: (dLat != null && dLng != null) ? LatLng(dLat, dLng) : null,
        priority: priority,
        vehiclePref: vehPref,
        sharePref: sharePref,
        earliestPickupMin: earliest != null ? timeToMinutes(earliest.toString()) : 0,
        latestDropMin:     latest   != null ? timeToMinutes(latest.toString())   : 1440,
      );
    }
    return map;
  }

  // ── Vehicle details + cost_per_km ─────────────────────────────────────────

  static Map<String, VehicleDetails> extractVehicleDetails(
      List<Map<String, dynamic>> vehRows) {
    final map = <String, VehicleDetails>{};

    for (final row in vehRows) {
      final vId = (findValue(row, ['vehicle', 'vehicle_id', 'id']) ?? row['vehicle_id'] ?? row['id'] ?? row['ID'])?.toString();
      if (vId == null) continue;

      final lat = _parseDouble(findValue(row, ['current_lat', 'start_lat', 'lat']) ?? row['current_lat']);
      final lng = _parseDouble(findValue(row, ['current_lng', 'start_lng', 'lng']) ?? row['current_lng']);

      dynamic availableFrom = findValue(row, ['available_from', 'start_time']) ?? row['available_from'];
      if (availableFrom is num) availableFrom = excelTimeToHHMMSS(availableFrom);

      final type = (findValue(row, ['type', 'category', 'class', 'vehicle_type']) ?? row['category'] ?? row['vehicle_type'] ?? 'Normal').toString();
      final fuel = (findValue(row, ['fuel', 'propulsion', 'engine', 'fuel_type']) ?? row['fuel_type'] ?? 'Electric').toString();
      final capacity = int.tryParse((findValue(row, ['capacity', 'seats', 'max_passengers']) ?? row['capacity'] ?? 4).toString()) ?? 4;

      // cost_per_km — used by analytics cost chart (matches ControlPanel.js)
      final costPerKm = double.tryParse((findValue(row, ['cost_per_km', 'cost', 'price_per_km']) ?? row['cost_per_km'] ?? 10).toString()) ?? 10.0;

      map[vId] = VehicleDetails(
        lat: lat,
        lng: lng,
        availableFrom: availableFrom?.toString() ?? '08:00:00',
        type: type,
        fuel: fuel,
        capacity: capacity,
        costPerKm: costPerKm,
      );
    }
    return map;
  }

  // ── Baseline sheet (NEW — mirrors ControlPanel.js baselineMap) ────────────

  static Map<String, Map<String, double>> extractBaseline(
      List<Map<String, dynamic>> baseRows) {
    final map = <String, Map<String, double>>{};
    for (final row in baseRows) {
      final empId = (findValue(row, ['employee_id', 'employee', 'id']) ?? row['employee_id'] ?? row['id'])?.toString();
      if (empId == null) continue;
      final cost = double.tryParse((findValue(row, ['baseline_cost', 'cost']) ?? row['baseline_cost'] ?? 0).toString()) ?? 0;
      final time = double.tryParse((findValue(row, ['baseline_time_min', 'time_min']) ?? row['baseline_time_min'] ?? 0).toString()) ?? 0;
      map[empId.trim().toLowerCase()] = {'cost': cost, 'time': time};
    }
    return map;
  }

  // ── Parse server CSV response ─────────────────────────────────────────────

  static List<Map<String, String>> parseServerCSV(String csvString) {
    if (csvString.isEmpty) return [];
    final lines = csvString.trim().split('\n');
    if (lines.length < 2) return [];
    final headers = lines[0].split(',').map((h) => h.trim()).toList();
    return lines.skip(1).map((line) {
      final values = line.split(',');
      final obj = <String, String>{};
      for (int i = 0; i < headers.length; i++) {
        obj[headers[i]] = i < values.length ? values[i].trim() : '';
      }
      return obj;
    }).where((r) => r['vehicle_id']?.isNotEmpty == true && r['employee_id']?.isNotEmpty == true).toList();
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
