# 🚀 Guía Rápida - Almacenamiento de Datos

## 5 Operaciones Más Comunes

### 1️⃣ Guardar Lectura de Gas
```dart
final reading = GasReading(
  zone: "Norte - Nivel 1",
  timestamp: DateTime.now(),
  co: 25.5, o2: 20.8, co2: 400.0, h2s: 0.5, temperatura: 25.0,
);
await db.insertGasReading(reading: reading);
```

### 2️⃣ Obtener Últimas Lecturas
```dart
final readings = await db.fetchLatestGasReadings(limit: 100);
for (var r in readings) {
  print("${r.zone}: CO=${r.co} ppm");
}
```

### 3️⃣ Obtener Estadísticas de Zona
```dart
final stats = await db.getGasStatistics(
  zone: "Norte - Nivel 1",
  limitMinutes: 60,
);
print("CO promedio: ${stats['CO']} ppm");
```

### 4️⃣ Crear Alerta
```dart
await db.createAlert(
  zone: "Norte - Nivel 1",
  message: "CO elevado",
  level: "warn",
);
```

### 5️⃣ Procesar Lectura + Alerta
```dart
final utils = DatabaseUtils(db);
final alertLevel = utils.getAlertLevel(reading);
if (alertLevel != 'info') {
  await utils.processAndStoreReading(reading);
}
```

---

## Rangos Válidos (Auto-validados)

| Gas | Rango | Unidad |
|-----|-------|--------|
| CO | 0-1000 | ppm |
| O2 | 0-100 | % |
| CO2 | 0-100 | % |
| CH4 | 0-100 | % |
| H2S | 0-100 | ppm |
| Temperatura | -40 a 80 | °C |

---

## Zonas Soportadas

```
"Norte - Nivel 1"    (ID: 1)
"Sur - Nivel 2"      (ID: 2)
"Este - Nivel 3"     (ID: 3)
"Oeste - Nivel 1"    (ID: 4)
"Central - Nivel 2"  (ID: 5)
```

---

## Niveles de Alerta

```
"info"   - Normal, sin problemas
"warn"   - Advertencia, revisar valores
"danger" - Peligro, acción inmediata
```

---

## Manejo de Errores

```dart
try {
  await db.insertGasReading(reading: reading);
} on ArgumentError catch (e) {
  // Error de validación (ej: valor fuera de rango)
  print("Validación: ${e.message}");
} on DatabaseException catch (e) {
  // Error de BD
  print("BD: ${e.message}");
}
```

---

## Conexión a BD

```dart
// Por defecto (localhost)
final db = DatabaseService();

// Personalizada
final db = DatabaseService(
  config: DbConfig(
    host: '192.168.1.100',
    port: 5432,
    database: 'miner_clc',
    username: 'postgres',
    password: 'contraseña',
  )
);

// Siempre cerrar al terminar
await db.close();
```

---

## Documentación

- **DATABASE_GUIDE.md** - Guía completa
- **ZONE_MAPPING_GUIDE.md** - Mapeo de columnas
- **IMPLEMENTATION_SUMMARY.md** - Resumen técnico

---

## Métodos Disponibles

### DatabaseService
- `fetchLatestGasReadings()` - Últimas lecturas
- `fetchGasHistory(zone)` - Historial por zona
- `fetchVentilation()` - Estado ventilación
- `fetchAlerts()` - Alertas
- `insertGasReading()` - Insertar lectura ✨
- `insertGasReadingsBatch()` - Insertar múltiples ✨
- `getGasStatistics()` - Estadísticas ✨
- `cleanOldReadings()` - Limpiar datos ✨
- `createAlert()` - Crear alerta
- `setVentilation()` - Configurar ventilación

### DatabaseUtils
- `generateTestData()`
- `isReadingSafe()`
- `getAlertLevel()`
- `processAndStoreReading()`
- `getZoneStatus()`
- `exportHistoricalData()`
- `performMaintenance()`
- `verifyIntegrity()`

---

## Tips

✅ Siempre usar `try/finally` con `db.close()`
✅ Usar `insertGasReadingsBatch()` para múltiples registros
✅ Las validaciones ocurren automáticamente
✅ Los nombres de zona se convierten automáticamente
✅ Ejecutar `performMaintenance()` semanalmente
✅ Revisar `verifyIntegrity()` antes de producción

---

## Ejemplo Completo

```dart
void main() async {
  final db = DatabaseService();
  final utils = DatabaseUtils(db);
  
  try {
    // 1. Crear lectura
    final reading = GasReading(
      zone: "Norte - Nivel 1",
      timestamp: DateTime.now(),
      co: 35.0,  // Valor elevado
      o2: 20.5,
      co2: 450.0,
      h2s: 0.5,
      temperatura: 25.0,
    );
    
    // 2. Detectar alerta y procesar
    final level = utils.getAlertLevel(reading);
    print("Nivel de alerta: $level");
    
    // 3. Guardar y crear alerta si es necesario
    await utils.processAndStoreReading(reading);
    
    // 4. Obtener estadísticas
    final stats = await db.getGasStatistics(
      zone: "Norte - Nivel 1",
      limitMinutes: 60,
    );
    print("Estadísticas: $stats");
    
  } finally {
    await db.close();
  }
}
```

---

**¿Necesitas ayuda?** Lee los documentos:
- Errores → `DATABASE_GUIDE.md` sección "Troubleshooting"
- Columnas → `ZONE_MAPPING_GUIDE.md`
- Implementación → `IMPLEMENTATION_SUMMARY.md`
