# Mapeo de Zonas y Columnas - Miner CLC

## 🗺️ Mapeo de IDs de Zona

El sistema interno usa `zona_id` (número), pero el código Dart convierte automáticamente a nombres descriptivos:

| zona_id | Nombre Descriptivo |
|---------|-------------------|
| 1 | "Norte - Nivel 1" |
| 2 | "Sur - Nivel 2" |
| 3 | "Este - Nivel 3" |
| 4 | "Oeste - Nivel 1" |
| 5 | "Central - Nivel 2" |

### Cómo Funciona la Conversión

**En el código Dart:**
```dart
// Usas nombres descriptivos
final reading = GasReading(
  zone: "Norte - Nivel 1",  // ← Nombre descriptivo
  // ...
);
```

**Internamente:**
```dart
// El DatabaseService convierte automáticamente a zona_id
final zoneId = _idToZona["Norte - Nivel 1"];  // Retorna: 1
INSERT INTO lecturas_gases (zona_id, ...) VALUES (1, ...)
```

**Al recuperar:**
```dart
// Se convierte de nuevo a nombre descriptivo
final readings = await db.fetchLatestGasReadings();
// Cada lectura tiene zone = "Norte - Nivel 1" (no zona_id)
```

---

## 📋 Conversión de Nombres de Columnas

El código Dart es flexible y soporta múltiples nombres de columnas:

### usuarios
| Columna Esperada | Alternativas |
|---|---|
| `usuario` | `username` |
| `password_hash` | `password` |
| `nombre` | - |
| `identificacion` | `documento`, `cedula` |
| `creado_en` | `created_at` |

### lecturas_gases
| Columna Esperada | Alternativas |
|---|---|
| `zona_id` | `zona`, `zone` |
| `registrado_en` | `timestamp`, `fecha`, `created_at` |
| `co` | `CO` |
| `o2` | `O2` |
| `co2` | `CO2` |
| `ch4` | `CH4` |
| `h2s` | `H2S` |
| `temperatura` | `temp` |

### ventilacion
| Columna Esperada | Alternativas |
|---|---|
| `zona_id` | `zona`, `zone` |
| `modo` | `mode` |
| `velocidad` | `speed` |
| `actualizado_en` | `updated_at`, `fecha`, `timestamp` |

### alertas
| Columna Esperada | Alternativas |
|---|---|
| `zona_id` | `zona`, `zone` |
| `mensaje` | `message`, `descripcion` |
| `tipo` | `nivel`, `level`, `severidad` |
| `creado_en` | `created_at`, `fecha`, `timestamp` |
| `resuelta` | `resolved` |

---

## 🔄 Flujo Completo de Datos

```
┌─────────────────────────────────────────────────────────────┐
│ SENSOR DE GASES                                             │
│ Genera valores: CO, O2, CO2, H2S, etc.                     │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│ APLICACIÓN DART (app)                                       │
│ GasReading(zone: "Norte - Nivel 1", co: 25.5, ...)        │
│ • Validación de datos (rangos permitidos)                  │
│ • Conversión de zone → zona_id                             │
│ • Manejo de errores                                        │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│ DATABASE SERVICE (Dart)                                      │
│ • insertGasReading()                                        │
│ • Determina columnas correctas                             │
│ • Ejecuta prepared statement                               │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│ POSTGRESQL                                                  │
│ INSERT INTO lecturas_gases                                 │
│ (zona_id=1, co=25.5, o2=20.8, ...)                        │
│ VALUES (1, 25.5, 20.8, ...)                               │
│                                                             │
│ • Índices optimizan búsqueda                              │
│ • Triggers actualizan timestamps                          │
│ • Vistas proporcionan estadísticas                        │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│ RECUPERACIÓN DE DATOS                                       │
│ • fetchLatestGasReadings()                                 │
│ • Convierte zona_id → "Norte - Nivel 1"                   │
│ • Retorna List<GasReading>                                │
└─────────────────────────────────────────────────────────────┘
```

---

## ✅ Validaciones Automáticas

Cuando insertamos una lectura, se valida:

```dart
final reading = GasReading(
  zone: "Norte - Nivel 1",  // ✓ Debe ser válida, no vacía
  timestamp: DateTime.now(),
  co: 25.5,                 // ✓ Debe estar entre 0-1000
  o2: 20.8,                 // ✓ Debe estar entre 0-100
  co2: 450.0,               // ✓ Debe estar entre 0-100
  ch4: null,                // ✓ Puede ser null
  h2s: 0.8,                 // ✓ Debe estar entre 0-100
  temperatura: 24.5,        // ✓ Debe estar entre -40 y 80
);

// Si algo falla → ArgumentError con mensaje descriptivo
// Si pasan validaciones → Se guarda en BD
```

---

## 🔍 Ejemplo: Insertar Lectura Completa

```dart
import 'package:miner_clc/db/database_service.dart';
import 'package:miner_clc/db/models.dart';

void main() async {
  final db = DatabaseService();
  
  try {
    // 1. Crear objeto de lectura
    final reading = GasReading(
      zone: "Norte - Nivel 1",
      timestamp: DateTime.now(),
      co: 15.5,
      o2: 20.5,
      co2: 400.0,
      ch4: null,
      h2s: 0.5,
      temperatura: 25.0,
    );
    
    // 2. Validación ocurre en constructor
    // Si hay error → ArgumentError.toString() describe el problema
    
    // 3. Insertar en BD
    await db.insertGasReading(reading: reading);
    print("✓ Lectura insertada");
    
    // 4. Recuperar última lectura
    final latest = await db.fetchLatestGasReadings(limit: 1);
    print("✓ Lectura recuperada: ${latest.first.zone}");
    // Output: "✓ Lectura recuperada: Norte - Nivel 1"
    
  } catch (e) {
    print("✗ Error: $e");
  } finally {
    await db.close();
  }
}
```

---

## 📊 Vista: Estadísticas por Zona

La BD ahora tiene vistas que agrupan por `zona_id`:

```sql
SELECT * FROM v_estadisticas_gases_ultima_hora;

-- Resultado:
-- zona_id | cantidad_lecturas | co_promedio | o2_promedio | ...
--    1    |       45          |    18.3     |    20.1     | ...
--    2    |       32          |    22.1     |    19.8     | ...
--    3    |       28          |    16.5     |    20.3     | ...
```

En Dart:
```dart
final stats = await db.getGasStatistics(
  zone: "Norte - Nivel 1",  // Se convierte a zona_id=1 internamente
  limitMinutes: 60
);
print(stats);
// Output: {CO: 18.3, O2: 20.1, ...}
```

---

## 🚀 Índices Creados para Performance

```sql
✓ idx_lecturas_gases_zona_id          -- Buscar por zona rápido
✓ idx_lecturas_gases_registrado_en    -- Buscar por fecha
✓ idx_lecturas_gases_zona_registrado  -- Combo: zona + fecha
✓ idx_alertas_zona_id                 -- Alertas por zona
✓ idx_alertas_resuelta                -- Alertas activas
✓ idx_ventilacion_zona_id             -- Estado de ventilación
✓ idx_usuarios_usuario                -- Login rápido
```

---

## 📱 Columnas Agregadas Recientemente

En la ejecución anterior del script SQL se agregaron:

### usuarios
- `updated_at` - Se actualiza automáticamente
- `email` - Contacto adicional

### lecturas_gases
- `created_at` - Timestamp de creación (ej: auditoría)

### ventilacion
- `created_at` - Cuándo se registró esta configuración

### alertas
- `nivel` - Puede complementar o reemplazar `tipo`
- `resolved_at` - Cuándo se resolvió
- `created_at` - Auditoria

---

## 💡 Notas Importantes

1. **zona_id vs zone_name**: 
   - BD usa `zona_id` (1, 2, 3...)
   - Dart API usa `zone` (nombres descriptivos)
   - Conversión automática en ambos sentidos

2. **Compatibilidad de Columnas**:
   - El código soporta múltiples nombres
   - Se prefiere el nombre más específico
   - Ej: en usuarios prefiere `usuario` sobre `username`

3. **Timestamps**:
   - `creado_en` / `created_at` - Cuándo se registró
   - `actualizado_en` / `updated_at` - Cuándo se modificó (auto-trigger)
   - `registrado_en` / `timestamp` - Para lecturas de sensores

4. **NULL values**:
   - `ch4` puede ser NULL si no se mide
   - `resolved_at` es NULL si alerta no está resuelta
   - El código maneja esto automáticamente

---

**Última actualización**: Script SQL ejecutado correctamente ✅
