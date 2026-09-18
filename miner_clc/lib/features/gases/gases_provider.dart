import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../db/database_service.dart';
import '../../db/models.dart';
import '../../services/alert_notification_service.dart';

class GasesProvider extends ChangeNotifier {
  GasesProvider({DatabaseService? db}) : _db = db ?? DatabaseService();

  final DatabaseService _db;

  bool _loading = false;
  String? _error;

  List<GasReading> _latest = const [];
  String? _selectedZone;
  List<GasReading> _history = const [];

  Timer? _poll;

  bool get isLoading => _loading;
  String? get error => _error;
  List<GasReading> get latest => _latest;
  String? get selectedZone => _selectedZone;
  List<GasReading> get history => _history;

  List<String> get zones => _latest.map((e) => e.zone).toSet().toList()..sort();

  Future<void> loadLatest() async {
    _setLoading(true);
    _error = null;
    try {
      _latest = await _db.fetchLatestGasReadings(limit: 400);
      _selectedZone ??= _latest.isNotEmpty ? _latest.first.zone : null;
      _checkDangerousReadings(_latest);
      notifyListeners();
      if (_selectedZone != null) {
        await loadHistory(zone: _selectedZone!);
      }
    } catch (e) {
      _error = 'Error cargando lecturas: $e';
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  void _checkDangerousReadings(List<GasReading> readings) {
    for (final r in readings) {
      if (r.ch4 != null && r.ch4! >= 2.0) {
        unawaited(AlertNotificationService().evaluateAndDispatchEmergency(
          zone: r.zone,
          gas: 'Metano CH4',
          value: r.ch4!,
          level: 'danger',
          message: 'Concentración crítica de CH4 (${r.ch4!.toStringAsFixed(2)}%). Riesgo inminente de explosión.',
        ));
      } else if (r.co != null && r.co! >= 50.0) {
        unawaited(AlertNotificationService().evaluateAndDispatchEmergency(
          zone: r.zone,
          gas: 'Monóxido de Carbono CO',
          value: r.co!,
          level: 'danger',
          message: 'Concentración letal de CO (${r.co!.toStringAsFixed(1)} ppm). Evacuación requerida.',
        ));
      } else if (r.o2 != null && r.o2! < 19.5) {
        unawaited(AlertNotificationService().evaluateAndDispatchEmergency(
          zone: r.zone,
          gas: 'Oxígeno O2',
          value: r.o2!,
          level: 'danger',
          message: 'Deficiencia crítica de Oxígeno O2 (${r.o2!.toStringAsFixed(1)}%). Atmósfera asfixiante.',
        ));
      } else if (r.h2s != null && r.h2s! >= 10.0) {
        unawaited(AlertNotificationService().evaluateAndDispatchEmergency(
          zone: r.zone,
          gas: 'Ácido Sulfhídrico H2S',
          value: r.h2s!,
          level: 'danger',
          message: 'Nivel tóxico de H2S (${r.h2s!.toStringAsFixed(1)} ppm).',
        ));
      }
    }
  }

  Future<void> loadHistory({required String zone}) async {
    _error = null;
    try {
      _selectedZone = zone;
      _history = await _db.fetchGasHistory(zone: zone, limit: 120);
      notifyListeners();
    } catch (e) {
      _error = 'Error cargando historial: $e';
      notifyListeners();
    }
  }

  void startPolling({Duration interval = const Duration(seconds: 3)}) {
    _poll?.cancel();
    _poll = Timer.periodic(interval, (_) {
      unawaited(loadLatest());
    });
  }

  void stopPolling() {
    _poll?.cancel();
    _poll = null;
  }

  void _setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }
}

