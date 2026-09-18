import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../db/database_service.dart';
import '../../db/models.dart';

class VentilacionProvider extends ChangeNotifier {
  VentilacionProvider({DatabaseService? db}) : _db = db ?? DatabaseService();

  final DatabaseService _db;

  bool _loading = false;
  String? _error;
  List<VentilationState> _states = const [];

  Timer? _poll;

  bool get isLoading => _loading;
  String? get error => _error;
  List<VentilationState> get states => _states;

  List<String> get zones => _states.map((e) => e.zone).toSet().toList()..sort();

  Future<void> load() async {
    _setLoading(true);
    _error = null;
    try {
      _states = await _db.fetchVentilation(limit: 300);
      notifyListeners();
    } catch (e) {
      _error = 'Error cargando ventilación: $e';
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> setMode(String zone, VentMode mode) async {
    _setLoading(true);
    _error = null;
    notifyListeners();
    try {
      final current = _states.where((s) => s.zone == zone).toList();
      int speed = current.isEmpty ? 0 : current.first.speed;
      
      // Si se enciende y la velocidad estaba en 0, ponerla en 100 por defecto para que ventile.
      if (mode == VentMode.on && speed == 0) {
        speed = 100;
      }
      
      await _db.setVentilation(zone: zone, mode: mode, speed: speed);
      await load();
    } catch (e) {
      _error = 'Error actualizando ventilación: $e';
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> setSpeed(String zone, int speed) async {
    _setLoading(true);
    _error = null;
    notifyListeners();
    try {
      final current = _states.where((s) => s.zone == zone).toList();
      final mode = current.isEmpty ? VentMode.auto : current.first.mode;
      await _db.setVentilation(zone: zone, mode: mode, speed: speed);
      await load();
    } catch (e) {
      _error = 'Error ajustando velocidad: $e';
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  void startPolling({Duration interval = const Duration(seconds: 2)}) {
    _poll?.cancel();
    _poll = Timer.periodic(interval, (_) {
      unawaited(load());
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

