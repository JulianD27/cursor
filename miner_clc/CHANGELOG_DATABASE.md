# Mejoras de Almacenamiento y Recuperación de Datos - Changelog

## 🎯 Cambios Implementados

### 1. **Métodos de Inserción de Datos** ✅ NUEVO

#### `insertGasReading(reading: GasReading)`
- Inserta una única lectura de gases con validación
- Valida automáticamente tipos de datos y rangos
- Maneja diferentes versiones de esquema

#### `insertGasReadingsBatch(readings: List<GasReading>)`
- Inserta múltiples lecturas de forma eficiente
- Continúa con próximas inserciones aunque algunas fallen
- Mejor rendimiento que llamadas individuales

---

### 2. **Validación de Datos** ✅ NUEVO

#### Rangos validados automáticamente:
- **CO**: 0-1000 ppm
- **O2**: 0-100%
- **CO2**: 0-100%
- **CH4**: 0-100%
- **H2S**: 0-100 ppm
- **Temperatura**: -40°C a 80°C

#### Validaciones en GasReading (modelo)
```dart
- Zona no puede estar vacía
- Al menos un valor de gas obligatorio
- Lanzamiento automático de excepciones si es inválido
```

---

### 3. **Estadísticas y Análisis** ✅ NUEVO

#### `getGasStatistics(zone, limitMinutes)`
- Calcula promedios de gases por zona
- Filter temporal configurable
- Retorna diccionario con estadísticas

```dart
final stats = await db.getGasStatistics(
  zone: "Norte - Nivel 1",
  limitMinutes: 60,  // últimas 60 minutos
);
// Resultado: {'CO': 15.5, 'O2': 20.3, ...}
```

---

### 4. **Mantenimiento de Base de Datos** ✅ NUEVO

#### `cleanOldReadings(retentionDays)`
- Elimina lecturas más antiguas que N días
- Optimiza almacenamiento automáticamente
- Retorna cantidad de registros eliminados

```dart
final deleted = await db.cleanOldReadings(retentionDays: 30);
print('Eliminadas: $deleted lecturas');
```

---

### 5. **Manejo Robusto de Errores** ✅ MEJORADO

#### Nueva clase: `DatabaseException`
```dart
catch (e) on DatabaseException {
  print('Error BD: ${e.message}');
}
```

Anteriormente: Solo `throws StateError`

---

### 6. **Modelos Mejorados (GasReading)** ✅ REFACTORIZADO

#### Nuevos métodos:
```dart
// Validación automática en constructor
reading.validate();

// Copiar con cambios
final updated = reading.copyWith(temperatura: 25.5);

// Serialización JSON
final json = reading.toJson();
```

#### Mejora anterior → nueva:
```dart
// Anterior: Sin validación
GasReading(zone: "", timestamp: now, co: 2000);

// Nueva: Con validación automática (lanza error)
GasReading(zone: "", timestamp: now, co: 2000);
// ArgumentError: CO fuera de rango: 2000 (0-1000 ppm)
```

---

### 7. **Utilidades Auxiliares** ✅ NUEVO

Crear archivo `lib/utils/database_utils.dart` con:

#### `DatabaseUtils` clase:
- `generateTestData()` - Crear datos de prueba
- `isReadingSafe()` - Verificar seguridad
- `getAlertLevel()` - Detectar nivel de alerta
- `processAndStoreReading()` - Procesar e insertar
- `getZoneStatus()` - Estado completo de zona
- `exportHistoricalData()` - Exportar datos
- `performMaintenance()` - Limpieza automática
- `verifyIntegrity()` - Verificar integridad

---

### 8. **Script de Inicialización SQL** ✅ NUEVO

Crear archivo `init_database.sql` con:
- Creación automática de tablas
- Índices para optimizar búsquedas
- Triggers para `updated_at`
- Vistas para estadísticas
- Datos de ejemplo

**Ejecución:**
```bash
psql -U postgres -f init_database.sql
```

---

### 9. **Documentación** ✅ NUEVO

Crear archivo `DATABASE_GUIDE.md` con:
- Ejemplos de uso para cada método
- Mejores prácticas
- Troubleshooting
- Configuración
- Esquema de tablas

---

## 📊 Comparativa: Antes vs Después

| Característica | Antes | Después |
|---|---|---|
| Lectura de gases | ✓ Sí | ✓ Sí |
| Escritura de gases | ❌ No | ✓ Sí |
| Validación de datos | ❌ No | ✓ Automática |
| Batch inserts | ❌ No | ✓ Sí |
| Estadísticas | ❌ No | ✓ Sí |
| Limpieza automática | ❌ No | ✓ Sí |
| Manejo de errores | ⚠️ Básico | ✓ Robusto |
| Documentación | ❌ Mínima | ✓ Completa |
| Utilidades | ❌ No | ✓ Extensivas |
| Modelos validados | ❌ No | ✓ Sí |

---

## 🚀 Cómo Usar las Nuevas Características

### Caso 1: Guardar una lectura de sensor
```dart
final reading = GasReading(
  zone: "Norte - Nivel 1",
  timestamp: DateTime.now(),
  co: 25.0,
  o2: 20.5,
  co2: 400.0,
  ch4: null,
  h2s: 0.5,
  temperatura: 25.0,
);

await db.insertGasReading(reading: reading);
```

### Caso 2: Procesar lectura con alertas automáticas
```dart
final utils = DatabaseUtils(db);
await utils.processAndStoreReading(reading);
// - Valida la lectura
// - La guarda
// - Crea alerta si es necesario
```

### Caso 3: Obtener estadísticas de una zona
```dart
final stats = await db.getGasStatistics(
  zone: "Norte - Nivel 1",
  limitMinutes: 60,
);
print("CO promedio: ${stats['CO']}");
```

### Caso 4: Mantenimiento automático
```dart
final result = await utils.performMaintenance(retentionDays: 30);
print("${result['deletedReadings']} lecturas eliminadas");
```

---

## 🔍 Validaciones Implementadas

### En GasReading (constructor)
```dart
✓ Zone no vacía
✓ Al menos un valor de gas presente
✓ CO: 0-1000 ppm
✓ O2: 0-100%
✓ CO2: 0-100%
✓ CH4: 0-100%
✓ H2S: 0-100 ppm
✓ Temperatura: -40 a 80°C
```

### En insertGasReading()
```dart
✓ Todas las validaciones de GasReading
✓ Existencia de tablas y columnas
✓ Conversión correcta de tipos
✓ Manejo de valores NULL opcionales
```

---

## 📈 Mejoras de Rendimiento

| Operación | Antes | Después |
|---|---|---|
| Insertar 100 lecturas | ~100 queries | ~100 queries (pero con validación) |
| Obtener estadísticas | N/A | 1 query con agregación |
| Limpieza de datos | Manual | Automática |
| Búsqueda con índices | Parcial | Optimizada |

---

## ⚙️ Cambios de Esquema SQL

### Nuevos índices:
```sql
✓ idx_lecturas_gases_zona
✓ idx_lecturas_gases_timestamp
✓ idx_lecturas_gases_zona_timestamp
✓ idx_alertas_zona
✓ idx_alertas_resuelta
✓ idx_alertas_created_at
✓ idx_ventilacion_zona
✓ idx_usuarios_username
```

### Nuevas vistas:
```sql
✓ v_estadisticas_gases_ultima_hora
✓ v_alertas_activas
```

### Nuevas funciones:
```sql
✓ actualizar_updated_at() - Trigger para timestamps
```

---

## 🔒 Seguridad

### Mejoras:
- ✓ Validación de entrada en modelos
- ✓ Prepared statements (ya existía)
- ✓ Rangos de valores verificados
- ✓ Excepciones descriptivas

### Recomendaciones:
- ⚠️ Usar contraseñas hasheadas (SHA-256)
- ⚠️ Implementar rate limiting
- ⚠️ Usar HTTPS en producción
- ⚠️ Backups automáticos diarios

---

## 📝 Próximos Pasos Recomendados

1. **Conexión con sensores**
   - Integrar lecturas en tiempo real
   - Usar `insertGasReading()` para cada medición

2. **Sistema de alertas**
   - RPC basado en `getAlertLevel()`
   - Crear alertas con `createAlert()`

3. **Dashboard de estadísticas**
   - Usar `getGasStatistics()` para gráficos
   - Mostrar `v_estadisticas_gases_ultima_hora`

4. **Exportación de datos**
   - Implementar `exportHistoricalData()`
   - Generar reportes CSV/PDF

5. **Sincronización**
   - Caché local con `GetStorage`
   - Sync offline/online con `insertGasReadingsBatch()`

---

## 📞 Soporte

Para problemas con:
- **Inserción de datos**: Ver DATABASE_GUIDE.md sección "Mejores Prácticas"
- **Validaciones**: Ver DATABASE_GUIDE.md sección "Manejo de Errores"
- **Performance**: Usar `verifyIntegrity()` de DatabaseUtils
- **SQL**: Revisar init_database.sql

---

**Última actualización**: 2 de mayo de 2026
**Versión**: 2.0.0
