// lib/utils/database_utils.dart
// Utilidades para facilitar operaciones comunes de base de datos

import 'package:miner_clc/db/database_service.dart';
import 'package:miner_clc/db/models.dart';

/// Clase auxiliar para operaciones frecuentes de base de datos
class DatabaseUtils {
  final DatabaseService db;

  DatabaseUtils(this.db);

  /// Genera datos de prueba con múltiples lecturas
  Future<void> generateTestData({
    List<String> zones = const [
      "Norte - Nivel 1",
      "Sur - Nivel 2",
      "Este - Nivel 3",
    ],
    int readingsPerZone = 10,
  }) async {
    final readings = <GasReading>[];
    DateTime baseTime = DateTime.now().subtract(Duration(hours: 24));

    for (final zone in zones) {
      for (int i = 0; i < readingsPerZone; i++) {
        readings.add(
          GasReading(
            zone: zone,
            timestamp: baseTime.add(Duration(hours: i)),
            co: 15.0 + (i % 10) + (i * 0.5),
            o2: 20.5 + (i % 2),
            co2: 400.0 + (i * 5),
            ch4: null,
            h2s: 0.5 + (i * 0.1),
            temperatura: 24.0 + (i % 5),
          ),
        );
      }
    }

    await db.insertGasReadingsBatch(readings: readings);
    print('✓ ${readings.length} lecturas de prueba creadas');
  }

  /// Valida que una lectura esté dentro de límites de seguridad
  bool isReadingSafe(GasReading reading) {
    // Límites de seguridad estrictos
    const Map<String, Map<String, double>> limits = {
      'CO': {'warn': 50, 'danger': 100},      // ppm
      'O2': {'warn': 18, 'danger': 16},       // %
      'CO2': {'warn': 5, 'danger': 10},       // %
      'CH4': {'warn': 1, 'danger': 5},        // %
      'H2S': {'warn': 10, 'danger': 20},      // ppm
    };

    if (reading.co != null && reading.co! > limits['CO']!['danger']!) return false;
    if (reading.o2 != null && reading.o2! < limits['O2']!['danger']!) return false;
    if (reading.co2 != null && reading.co2! > limits['CO2']!['danger']!) return false;
    if (reading.ch4 != null && reading.ch4! > limits['CH4']!['danger']!) return false;
    if (reading.h2s != null && reading.h2s! > limits['H2S']!['danger']!) return false;

    return true;
  }

  /// Obtiene el nivel de alerta para una lectura
  String getAlertLevel(GasReading reading) {
    const Map<String, Map<String, double>> limits = {
      'CO': {'warn': 50, 'danger': 100},
      'O2': {'warn': 18, 'danger': 16},
      'CO2': {'warn': 5, 'danger': 10},
      'CH4': {'warn': 1, 'danger': 5},
      'H2S': {'warn': 10, 'danger': 20},
    };

    // Revisar límites de peligro
    if (reading.co != null && reading.co! > limits['CO']!['danger']!) return 'danger';
    if (reading.o2 != null && reading.o2! < limits['O2']!['danger']!) return 'danger';
    if (reading.co2 != null && reading.co2! > limits['CO2']!['danger']!) return 'danger';
    if (reading.ch4 != null && reading.ch4! > limits['CH4']!['danger']!) return 'danger';
    if (reading.h2s != null && reading.h2s! > limits['H2S']!['danger']!) return 'danger';

    // Revisar límites de advertencia
    if (reading.co != null && reading.co! > limits['CO']!['warn']!) return 'warn';
    if (reading.o2 != null && reading.o2! < limits['O2']!['warn']!) return 'warn';
    if (reading.co2 != null && reading.co2! > limits['CO2']!['warn']!) return 'warn';
    if (reading.ch4 != null && reading.ch4! > limits['CH4']!['warn']!) return 'warn';
    if (reading.h2s != null && reading.h2s! > limits['H2S']!['warn']!) return 'warn';

    return 'info';
  }

  /// Procesa una lectura y crea alertas si es necesario
  Future<void> processAndStoreReading(GasReading reading) async {
    try {
      // Detectar problemas
      final alertLevel = getAlertLevel(reading);

      // Guardar lectura
      await db.insertGasReading(reading: reading);

      // Crear alerta si es necesario
      if (alertLevel != 'info') {
        final message = _buildAlertMessage(reading, alertLevel);
        await db.createAlert(
          zone: reading.zone,
          message: message,
          level: alertLevel,
        );
      }

      print('✓ Lectura procesada: ${reading.zone}');
    } catch (e) {
      print('✗ Error procesando lectura: $e');
      rethrow;
    }
  }

  String _buildAlertMessage(GasReading reading, String level) {
    final warnings = <String>[];

    if (reading.co != null && reading.co! > 100) {
      warnings.add('CO: ${reading.co!.toStringAsFixed(1)} ppm');
    }
    if (reading.o2 != null && reading.o2! < 16) {
      warnings.add('O2: ${reading.o2!.toStringAsFixed(1)}%');
    }
    if (reading.co2 != null && reading.co2! > 10) {
      warnings.add('CO2: ${reading.co2!.toStringAsFixed(1)}%');
    }
    if (reading.h2s != null && reading.h2s! > 20) {
      warnings.add('H2S: ${reading.h2s!.toStringAsFixed(1)} ppm');
    }

    return 'Alerta de ${level == 'danger' ? 'PELIGRO' : 'ADVERTENCIA'}: ${warnings.join(', ')}';
  }

  /// Obtiene el estado general de una zona
  Future<Map<String, dynamic>> getZoneStatus(String zone) async {
    try {
      final readings = await db.fetchGasHistory(zone: zone, limit: 30);
      final stats = await db.getGasStatistics(zone: zone, limitMinutes: 120);
      final alerts = await db.fetchAlerts(zone: zone, resolved: false);

      return {
        'zone': zone,
        'lastReading': readings.isNotEmpty ? readings.first : null,
        'readingCount': readings.length,
        'statistics': stats,
        'activeAlerts': alerts.length,
        'isHealthy': readings.isEmpty || getAlertLevel(readings.first) == 'info',
      };
    } catch (e) {
      return {
        'zone': zone,
        'error': e.toString(),
      };
    }
  }

  /// Descarga datos históricos en un período
  Future<List<GasReading>> exportHistoricalData({
    required String zone,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final readings = await db.fetchGasHistory(zone: zone, limit: 1000);
    return readings
        .where((r) => r.timestamp.isAfter(startDate) && r.timestamp.isBefore(endDate))
        .toList();
  }

  /// Realiza limpieza y mantenimiento de la base de datos
  Future<Map<String, int>> performMaintenance({int retentionDays = 30}) async {
    try {
      final deletedOldReadings = await db.cleanOldReadings(retentionDays: retentionDays);

      return {
        'deletedReadings': deletedOldReadings,
      };
    } catch (e) {
      print('Error durante mantenimiento: $e');
      rethrow;
    }
  }

  /// Verifica integridad de la base de datos
  Future<bool> verifyIntegrity() async {
    try {
      // Verificar que podamos leer datos de cada tabla
      final latestReadings = await db.fetchLatestGasReadings(limit: 1);
      final ventilation = await db.fetchVentilation(limit: 1);
      final alerts = await db.fetchAlerts(limit: 1);

      // Si todos los queries funcionan, la DB está bien
      return true;
    } catch (e) {
      print('✗ Error en integridad de BD: $e');
      return false;
    }
  }
}
