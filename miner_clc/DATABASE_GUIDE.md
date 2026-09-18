# Guía de Almacenamiento y Recuperación de Datos - Miner CLC

## 📋 Descripción General

El sistema utiliza PostgreSQL como base de datos principal con las siguientes tablas:
- **usuarios**: Datos de autenticación y perfil
- **lecturas_gases**: Mediciones de sensores de gas
- **ventilacion**: Estado de sistemas de ventilación
- **alertas**: Alertas generadas por el sistema

## 🔧 Operaciones Clave

### 1. **Lectura de Datos**

#### Obtener últimas lecturas de gases
```dart
final readings = await db.fetchLatestGasReadings(limit: 200);
```

#### Obtener historial de una zona específica
```dart
final history = await db.fetchGasHistory(zone: "Norte - Nivel 1", limit: 120);
```

#### Obtener alertas
```dart
final alerts = await db.fetchAlerts(
  resolved: false,  // solo sin resolver
  zone: "Norte - Nivel 1",
  limit: 200
);
```

#### Obtener estado de ventilación
```dart
final ventState = await db.fetchVentilation(limit: 200);
```

### 2. **Inserción de Datos**

#### Guardar nueva lectura de gas (✨ NUEVO)
```dart
await db.insertGasReading(
  reading: GasReading(
    zone: "Norte - Nivel 1",
    timestamp: DateTime.now(),
    co: 15.5,
    o2: 20.5,
    co2: 500.0,
    ch4: null,
    h2s: 0.5,
    temperatura: 25.5,
  )
);
```

**Validaciones automáticas:**
- Zona no puede estar vacía
- Al menos un valor de gas debe ser válido
- Rangos permitidos:
  - CO: 0-1000 ppm
  - O2: 0-100 %
  - CO2: 0-100 %
  - CH4: 0-100 %
  - H2S: 0-100 ppm
  - Temperatura: -40 a 80°C

#### Guardar múltiples lecturas
```dart
await db.insertGasReadingsBatch(readings: [
  reading1,
  reading2,
  reading3,
]);
```

#### Crear alerta
```dart
await db.createAlert(
  zone: "Norte - Nivel 1",
  message: "Nivel de CO excedido",
  level: "danger",  // info, warn, danger
);
```

#### Actualizar ventilación
```dart
await db.setVentilation(
  zone: "Norte - Nivel 1",
  mode: VentMode.on,
  speed: 75,  // 0-100
);
```

### 3. **Estadísticas y Análisis**

#### Obtener estadísticas por zona
```dart
final stats = await db.getGasStatistics(
  zone: "Norte - Nivel 1",
  limitMinutes: 60,
);
// Retorna: {'CO': 15.5, 'O2': 20.3, 'temperatura': 25.1, ...}
```

#### Limpiar datos antiguos
```dart
final deleted = await db.cleanOldReadings(retentionDays: 30);
print('Lecturas eliminadas: $deleted');
```

## 🛡️ Manejo de Errores

Todos los métodos pueden lanzar excepciones:

```dart
try {
  await db.insertGasReading(reading: reading);
} on ArgumentError catch (e) {
  // Error de validación de datos
  print('Validación: ${e.message}');
} on DatabaseException catch (e) {
  // Error de base de datos
  print('Database: ${e.message}');
} catch (e) {
  // Error general
  print('Error: $e');
}
```

## 📊 Esquema de Tablas

### usuarios
```sql
- id (integer, primary key)
- usuario (varchar) - Nombre de usuario único
- password_hash (varchar)
- nombre (varchar)
- identificacion (varchar)
- edad (integer)
- ubicacion (varchar)
- nacimiento (date)
- rol (varchar)
- creado_en (timestamp)
- updated_at (timestamp) - ✨ NUEVO
- email (varchar) - ✨ NUEVO
```

### lecturas_gases
```sql
- id (integer, primary key)
- zona_id (integer) - ID de la zona
- co (numeric) - Monóxido de carbono (ppm)
- o2 (numeric) - Oxígeno (%)
- co2 (numeric) - Dióxido de carbono (%)
- ch4 (numeric) - Metano (%)
- h2s (numeric) - Sulfuro de hidrógeno (ppm)
- temperatura (numeric) - Temperatura (°C)
- estado (varchar)
- registrado_en (timestamp) - Fecha de registro
- created_at (timestamp) - ✨ NUEVO
```

### ventilacion
```sql
- id (integer, primary key)
- zona_id (integer) - ID de la zona
- estado (varchar)
- velocidad (integer) - 0-100
- modo (varchar) - ON, OFF, AUTO
- actualizado_en (timestamp)
- created_at (timestamp) - ✨ NUEVO
```

### alertas
```sql
- id (integer, primary key)
- zona_id (integer) - ID de la zona
- mensaje (text)
- tipo (varchar) - Tipo de alerta
- resuelta (boolean)
- creado_en (timestamp)
- nivel (varchar) - info, warn, danger ✨ NUEVO
- resolved_at (timestamp) - ✨ NUEVO
- created_at (timestamp) - ✨ NUEVO
```

### Mapeo de Zonas
El sistema usa `zona_id` en lugar de nombres de zona para referenciar:
- 1: "Norte - Nivel 1"
- 2: "Sur - Nivel 2"
- 3: "Este - Nivel 3"
- 4: "Oeste - Nivel 1"
- 5: "Central - Nivel 2"

## ✅ Mejores Prácticas

### 1. **Validación Antes de Guardar**
```dart
// ✅ BIEN: Validar antes de insertar
if (reading.co != null && reading.co! > 50) {
  await db.createAlert(
    zone: reading.zone,
    message: "CO crítico: ${reading.co} ppm"
  );
}
await db.insertGasReading(reading: reading);

// ❌ MAL: No validar
await db.insertGasReading(reading: reading);
```

### 2. **Usar Batch Para Múltiples Inserciones**
```dart
// ✅ BIEN: Usar batch
await db.insertGasReadingsBatch(readings: allReadings);

// ❌ MAL: Loop simple
for (final r in allReadings) {
  await db.insertGasReading(reading: r);
}
```

### 3. **Manejo de Conexiones**
```dart
// ✅ BIEN: Cerrar conexión cuando termines
final db = DatabaseService();
try {
  await db.fetchLatestGasReadings();
} finally {
  await db.close();
}

// ❌ MAL: No cerrar
final db = DatabaseService();
await db.fetchLatestGasReadings();
// Conexión abierta indefinidamente
```

### 4. **Usar Límites en Queries**
```dart
// ✅ BIEN: Especificar límite
final recent = await db.fetchLatestGasReadings(limit: 100);

// ❌ MAL: Sin límite puede traer demasiados datos
final all = await db.fetchLatestGasReadings();
```

### 5. **Gestionar Almacenamiento**
```dart
// Ejecutar periódicamente (ej: semanal)
await db.cleanOldReadings(retentionDays: 30);
```

## 🔌 Configuración de Conexión

### Predeterminada (Localhost)
```dart
final db = DatabaseService();
// Usa: localhost:5432, BD: miner_clc, usuario: postgres
```

### Personalizada
```dart
final db = DatabaseService(
  config: DbConfig(
    host: '192.168.1.100',
    port: 5432,
    database: 'miner_clc',
    username: 'postgres',
    password: 'miPassword123',
  )
);
```

## 📱 Ejemplo Completo

```dart
import 'package:miner_clc/db/database_service.dart';
import 'package:miner_clc/db/models.dart';

void main() async {
  final db = DatabaseService();

  try {
    // 1. Crear lectura
    final reading = GasReading(
      zone: "Norte - Nivel 1",  // Nombre descriptivo (la BD usa zona_id internamente)
      timestamp: DateTime.now(),
      co: 25.5,
      o2: 20.8,
      co2: 450.0,
      ch4: null,
      h2s: 0.8,
      temperatura: 24.5,
    );

    // 2. Guardar lectura
    await db.insertGasReading(reading: reading);
    print("Lectura guardada exitosamente");

    // 3. Obtener estadísticas
    final stats = await db.getGasStatistics(
      zone: "Norte - Nivel 1",
      limitMinutes: 60,
    );
    print("Promedio CO: ${stats['CO']?.toStringAsFixed(2)} ppm");

    // 4. Crear alerta si es necesario
    if (reading.co! > 30) {
      await db.createAlert(
        zone: reading.zone,
        message: "Nivel de CO elevado",
        level: "warn",
      );
    }

    // 5. Obtener alertas sin resolver
    final alerts = await db.fetchAlerts(resolved: false);
    print("Alertas activas: ${alerts.length}");

  } catch (e) {
    print("Error: $e");
  } finally {
    await db.close();
  }
}
```

## 🚨 Troubleshooting

### Error: "PostgreSQL connection refused"
```
✓ Verificar que PostgreSQL está corriendo
✓ Verificar host y puerto en DbConfig
✓ Verificar credenciales
```

### Error: "Table not found"
```
✓ Ejecutar script de creación de tablas
✓ Verificar nombre exacto de tabla
✓ Verificar permisos del usuario
```

### Datos perdidos después de insertar
```
✓ Verificar que la inserción no lanzó excepción
✓ Verificar que await se usó correctamente
✓ Revisar logs de PostgreSQL
```

## 📈 Monitoreo

Se recomienda implementar:
- Logs de inserciones
- Métricas de conexión
- Alertas de espacio en disco
- Backups automáticos diarios

