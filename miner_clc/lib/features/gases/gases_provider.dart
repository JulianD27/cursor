import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../db/database_service.dart';
import '../../db/models.dart';

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

