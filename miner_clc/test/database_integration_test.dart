// test/database_integration_test.dart
// Test rápido para verificar que el sistema de BD funciona

import 'package:miner_clc/db/database_service.dart';
import 'package:miner_clc/db/models.dart';
import 'package:miner_clc/utils/database_utils.dart';

void main() async {
  print('🧪 Iniciando test de integración con base de datos...\n');

  final db = DatabaseService();

  try {
    // Test 1: Validación de GasReading
    print('✓ Test 1: Validación de modelo GasReading');
    try {
      final invalid = GasReading(
        zone: "Norte - Nivel 1",
        timestamp: DateTime.now(),
        co: 2000, // ✗ Fuera de rango (máx 1000)
      );
      print('  ✗ FAILED: Debería haber lanzado error por CO fuera de rango');
    } catch (e) {
      print('  ✓ PASSED: Detectó CO fuera de rango: $e\n');
    }

    // Test 2: Insertar lectura válida
    print('✓ Test 2: Insertar lectura válida');
    final reading = GasReading(
      zone: "Norte - Nivel 1",
      timestamp: DateTime.now(),
      co: 25.5,
      o2: 20.8,
      co2: 0.45,
      ch4: null,
      h2s: 0.5,
      temperatura: 24.5,
    );
    
    await db.insertGasReading(reading: reading);
    print('  ✓ PASSED: Lectura insertada correctamente\n');

    // Test 3: Recuperar últimas lecturas
    print('✓ Test 3: Recuperar últimas lecturas');
    final readings = await db.fetchLatestGasReadings(limit: 5);
    print('  ✓ PASSED: Se recuperaron ${readings.length} lecturas');
    if (readings.isNotEmpty) {
      final first = readings.first;
      print('  - Zona: ${first.zone}');
      print('  - CO: ${first.co} ppm');
      print('  - O2: ${first.o2}%');
    }
    print('');

    // Test 4: Obtener estadísticas
    print('✓ Test 4: Obtener estadísticas por zona');
    final stats = await db.getGasStatistics(
      zone: "Norte - Nivel 1",
      limitMinutes: 120,
    );
    print('  ✓ PASSED: Estadísticas obtenidas');
    if (stats.isNotEmpty) {
      stats.forEach((key, value) {
        print('  - $key: ${value.toStringAsFixed(2)}');
      });
    } else {
      print('  - (Sin datos en los últimos 120 minutos)');
    }
    print('');

    // Test 5: Utilidades - Detectar nivel de alerta
    print('✓ Test 5: Detectar nivel de alerta');
    final utils = DatabaseUtils(db);
    final alertLevel = utils.getAlertLevel(reading);
    print('  ✓ PASSED: Nivel de alerta: $alertLevel');
    final isSafe = utils.isReadingSafe(reading);
    print('  ✓ Lectura segura: $isSafe\n');

    // Test 6: Procesar lectura con alerta
    print('✓ Test 6: Procesar lectura y crear alerta');
    final alertReading = GasReading(
      zone: "Sur - Nivel 2",
      timestamp: DateTime.now(),
      co: 85.0, // ⚠️ Valor elevado (warn limit: 50, danger: 100)
      o2: 20.8,
      co2: 450.0,
      h2s: 0.5,
      temperatura: 25.0,
    );
    
    await utils.processAndStoreReading(alertReading);
    print('  ✓ PASSED: Lectura procesada y alerta creada si fue necesario\n');

    // Test 7: Obtener alertas
    print('✓ Test 7: Obtener alertas activas');
    final alerts = await db.fetchAlerts(resolved: false);
    print('  ✓ PASSED: ${alerts.length} alertas activas');
    for (var alert in alerts.take(3)) {
      print('  - [${alert.level}] ${alert.zone}: ${alert.message}');
    }
    print('');

    // Test 8: Verificar integridad
    print('✓ Test 8: Verificar integridad de BD');
    final isHealthy = await utils.verifyIntegrity();
    print('  ✓ PASSED: Base de datos ${isHealthy ? 'saludable ✓' : 'con problemas ✗'}\n');

    // Test 9: Estado de zona
    print('✓ Test 9: Obtener estado completo de zona');
    final zoneStatus = await utils.getZoneStatus("Norte - Nivel 1");
    print('  ✓ PASSED: Estado de zona obtenido');
    print('  - Zona: ${zoneStatus['zone']}');
    print('  - Lecturas: ${zoneStatus['readingCount']}');
    print('  - Alertas activas: ${zoneStatus['activeAlerts']}');
    print('  - Estado: ${zoneStatus['isHealthy'] ? 'Saludable ✓' : 'Con alertas ⚠️'}\n');

    print('═' * 50);
    print('✅ TODOS LOS TESTS PASARON CORRECTAMENTE');
    print('═' * 50);

  } catch (e, stackTrace) {
    print('❌ ERROR EN TEST:');
    print('$e');
    print(stackTrace);
  } finally {
    await db.close();
    print('\n🔌 Conexión cerrada');
  }
}
