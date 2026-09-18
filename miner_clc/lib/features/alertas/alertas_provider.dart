import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../db/database_service.dart';
import '../../db/models.dart';
import '../../services/alert_notification_service.dart';

class AlertasFilters {
  const AlertasFilters({this.zone, this.resolved});
  final String? zone;
  final bool? resolved;

  AlertasFilters copyWith({String? zone, bool? resolved, bool clearZone = false, bool clearResolved = false}) {
    return AlertasFilters(
      zone: clearZone ? null : (zone ?? this.zone),
      resolved: clearResolved ? null : (resolved ?? this.resolved),
    );
  }
}

class AlertasProvider extends ChangeNotifier {
  AlertasProvider({DatabaseService? db}) : _db = db ?? DatabaseService();

  final DatabaseService _db;

  bool _loading = false;
  String? _error;
  List<MinerAlert> _alerts = const [];
  AlertasFilters _filters = const AlertasFilters();

  Timer? _poll;

  bool get isLoading => _loading;
  String? get error => _error;
  List<MinerAlert> get alerts => _alerts;
  AlertasFilters get filters => _filters;

  Future<void> load() async {
    _setLoading(true);
    _error = null;
    try {
      _alerts = await _db.fetchAlerts(
        resolved: _filters.resolved,
        zone: _filters.zone,
        limit: 300,
      );
      notifyListeners();
    } catch (e) {
      _error = 'Error cargando alertas: $e';
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  void setFilters(AlertasFilters f) {
    _filters = f;
    notifyListeners();
    unawaited(load());
  }

  Future<void> create({required String zone, required String message, String level = 'warn'}) async {
    _error = null;
    try {
      await _db.createAlert(zone: zone, message: message, level: level);
      await load();

      // Auto-despacho de notificación al celular del ingeniero (Telegram / Twilio)
      if (level.toLowerCase().contains('danger') ||
          level.toLowerCase().contains('peligro') ||
          level.toLowerCase().contains('warn')) {
        unawaited(AlertNotificationService().evaluateAndDispatchEmergency(
          zone: zone,
          gas: 'Protocolo de Seguridad',
          value: 1.0,
          level: level,
          message: message,
        ));
      }
    } catch (e) {
      _error = 'Error creando alerta: $e';
      notifyListeners();
    }
  }

  Future<void> resolve(String id) async {
    _error = null;
    try {
      await _db.markAlertResolved(id: id);
      await load();
    } catch (e) {
      _error = 'Error resolviendo alerta: $e';
      notifyListeners();
    }
  }

  void startPolling({Duration interval = const Duration(seconds: 3)}) {
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

