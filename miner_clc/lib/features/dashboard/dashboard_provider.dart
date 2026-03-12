import 'package:flutter/foundation.dart';

import '../../db/database_service.dart';
import '../../db/models.dart';

class DashboardSummary {
  const DashboardSummary({
    required this.activeZones,
    required this.recentAlerts,
    required this.latestReadings,
  });

  final List<String> activeZones;
  final List<MinerAlert> recentAlerts;
  final List<GasReading> latestReadings;
}

class DashboardProvider extends ChangeNotifier {
  DashboardProvider({DatabaseService? db}) : _db = db ?? DatabaseService();

  final DatabaseService _db;

  bool _loading = false;
  String? _error;
  DashboardSummary? _summary;

  bool get isLoading => _loading;
  String? get error => _error;
  DashboardSummary? get summary => _summary;

  Future<void> load() async {
    _setLoading(true);
    _error = null;
    try {
      final alerts = await _db.fetchAlerts(limit: 10);
      final gases = await _db.fetchLatestGasReadings(limit: 100);
      final zones = gases.map((e) => e.zone).toSet().toList()..sort();
      _summary = DashboardSummary(
        activeZones: zones,
        recentAlerts: alerts.take(8).toList(),
        latestReadings: gases.take(12).toList(),
      );
      notifyListeners();
    } catch (e) {
      _error = 'Error cargando dashboard: $e';
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }
}

