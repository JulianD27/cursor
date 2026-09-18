# ANEXO B: CASOS, RESULTADOS Y DEFECTOS REGISTRADOS EN LAS PRUEBAS DE INTEGRACIÓN

**Proyecto:** MINER CLC — Sistema de Monitoreo Ambiental y Seguridad en Minería Subterránea  
**Programa:** Ingeniería de Sistemas / Software  
**Nivel Académico:** VII Semestre  
**Vigencia:** 2026-1 / 2026-2  
**Fecha de Ejecución:** 14 de Septiembre de 2026  
**Resultado Global:** 100% Casos Exitosos (9/9) — Estado APROBADO  

---

## 1. OBJETIVO Y ALCANCE DE LAS PRUEBAS DE INTEGRACIÓN

El objetivo de este anexo es comprobar el correcto acoplamiento, interoperabilidad y flujo de datos entre los módulos centrales de **MINER CLC**:
- **Módulo de Autenticación & Google OAuth:** Validación de cuentas reales de Google, usuarios locales y hashing criptográfico SHA-256.
- **Módulo de Sensores Ambientales:** Validación de rangos fisiológicos de gases (CO, O2, CO2, CH4, H2S, temperatura) y persistencia transaccional.
- **Módulo de Detección de Riesgos:** Generación y cierre de alertas críticas en PostgreSQL.
- **Módulo de Ventilación:** Transición bidireccional entre modo Automático inteligente y modo Manual forzado.
- **Módulo de Auditoría y Trazabilidad:** Inserción y consulta en `auditoria_logs`.
- **Módulo de Respaldo de Datos:** Integridad y control SHA-256 en `respaldos_historial`.
- **Módulo de Asistencia Inteligente (Chatbot):** Clasificación semántica de intenciones y generación de respuestas técnicas operativas.

---

## 2. AMBIENTE DE PRUEBAS

- **Sistema Operativo:** Microsoft Windows 11 Pro x64.
- **Motor de Base de Datos:** PostgreSQL 16 (Servicio local en puerto 5432, base de datos `miner_clc`).
- **Framework y Lenguajes:** Dart SDK 3.11+, Flutter 3.x, Python 3.13.2.
- **Harness de Ejecución Automatizada:** [`test/full_integration_test.py`](file:///c:/Users/Asus%20Vivobook/Documents/cursor/miner_clc/test/full_integration_test.py).

---

## 3. MATRIZ DE CASOS DE PRUEBA DE INTEGRACIÓN

| ID Caso | Módulo | Precondición | Datos de Entrada | Resultado Esperado | Resultado Obtenido | Estado |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **IT-01** | Autenticación Google Real | Servicio BD activo, tabla `usuarios` ampliada V3 | `email`: "minero.seguridad@gmail.com", `name`: "Julian Minero", `provider`: "google" | Registro de cuenta con `auth_provider = 'google'`, `email_verificado = TRUE` y generación de sesión | Usuario registrado e identificado con ID único, email verificado y auditoría registrada | **PASSED** |
| **IT-02** | Seguridad de Credenciales | Esquema de usuarios con columna `password_hash` | `user`: "operador_norte", `pass`: "ClaveSegura2026*" | Contraseña almacenada estrictamente como hash SHA-256 hexadecimal (64 caracteres), nunca en texto plano | Hash almacenado: `bdca7274b6095faa...`, coincidencia exacta en verificación | **PASSED** |
| **IT-03** | Inserción de Gases | Zona 1 configurada en tabla de mapeo | Zona: 1, CO: 24.5 ppm, O2: 20.8%, CO2: 420 ppm, CH4: 0.4%, Temp: 23.5°C | Lectura validada en rangos físicos e insertada con timestamp en `lecturas_gases` | Registro guardado con ID 7267, integridad referencial confirmada | **PASSED** |
| **IT-04** | Disparo de Alertas Críticas | Sensores detectan anomalía en Zona 3 | Concentración CH4: 2.1% (Supera umbral legal de 2.0%) | Generación de alerta con severidad `danger`, mensaje de evacuación y `resuelta = FALSE` | Alerta ID 60 creada con nivel `danger` en tiempo real | **PASSED** |
| **IT-05** | Control de Ventilación | Ventilador Zona 3 en estado operativo | Transición de AUTO (85%) a MANUAL (100% de potencia) | Actualización atómica en `ventilacion` respetando restricción de unicidad por zona | Ventilación ajustada a ON - 100% (Modo: MANUAL), `actualizado_en = NOW()` | **PASSED** |
| **IT-06** | Logging de Auditoría | Tabla `auditoria_logs` creada | Evento: 'TEST_INTEGRACION', Módulo: 'SISTEMA', Nivel: 'INFO' | Registro persistente con usuario, acción, módulo y timestamp | Log persistido con ID 3 en PostgreSQL | **PASSED** |
| **IT-07** | Control Criptográfico de Respaldo | Directorio `backups/` accesible | Archivo: `backup_test_it07.sql`, tamaño: 1 MB | Registro en `respaldos_historial` con hash SHA-256 verificable | Respaldo auditado con checksum `4564daa67eb09b2b...` | **PASSED** |
| **IT-08** | Resolución de Alertas | Alerta crítica activa en sistema (ID 60) | Acción de resolución del operador minero | Actualización de `resuelta = TRUE` y estampado de `resolved_at = NOW()` | Alerta 60 resuelta con timestamp exacto de atención | **PASSED** |
| **IT-09** | Motor NLP del Chatbot | Base de conocimiento cargada en memoria | Query: *"¿cuál es el límite del metano ch4?"* | Detección de palabras clave `metano`, `ch4` y retorno de protocolo de emergencia y umbral 2.0% | Consulta mapeada con éxito, respuesta detallada generada | **PASSED** |

---

## 4. REGISTRO DE DEFECTOS (BUG TRACKING) Y CORRECCIONES APLICADAS

Durante la fase de integración se identificaron y subsanaron los siguientes defectos:

### Defecto DEF-01: Violación de Restricción de Unicidad en Tabla `ventilacion`
- **Severidad:** Media (Bloqueante en actualización de ventiladores existentes).
- **Descripción:** Al intentar insertar un nuevo estado de ventilación para una zona que ya tenía registro, PostgreSQL arrojaba el error:
  `ERROR: llave duplicada viola restricción de unicidad «ventilacion_zona_id_key»`.
- **Causa Raíz:** La tabla `ventilacion` mantiene un único registro por zona (`UNIQUE(zona_id)`), por lo que una inserción directa (`INSERT INTO`) falla cuando la zona ya fue creada previamente.
- **Corrección Aplicada:** Se implementó la sentencia de inserción/actualización atómica (**UPSERT**) en SQL:
  ```sql
  INSERT INTO ventilacion (zona_id, estado, velocidad, modo, actualizado_en)
  VALUES (%s, %s, %s, %s, NOW())
  ON CONFLICT (zona_id) DO UPDATE
  SET estado = EXCLUDED.estado, velocidad = EXCLUDED.velocidad, modo = EXCLUDED.modo, actualizado_en = NOW();
  ```
- **Estado:** ✅ CERRADO / VERIFICADO.

---

### Defecto DEF-02: Aborto en Cadena de Transacciones PostgreSQL en Suite de Pruebas
- **Severidad:** Alta (Afectaba ejecución secuencial de pruebas automatizadas).
- **Descripción:** Tras el fallo de una prueba, las siguientes pruebas fallaban automáticamente con el mensaje:
  `ERROR: transacción abortada, las órdenes serán ignoradas hasta el fin de bloque de transacción`.
- **Causa Raíz:** El driver `psycopg2` mantenía una transacción global abierta que entraba en estado de error al capturar una excepción no manejada dentro del bloque.
- **Corrección Aplicada:** Se configuró `conn.autocommit = True` en el harness de prueba, garantizando que cada caso de prueba ejecute su propia transacción aislada sin interrumpir el flujo general.
- **Estado:** ✅ CERRADO / VERIFICADO.

---

### Defecto DEF-03: Posibilidad de Registro con Correos Desechables / Temporales
- **Severidad:** Media (Riesgo de seguridad y calidad de datos).
- **Descripción:** En la versión previa, el formulario permitía ingresar cualquier correo ficticio (ej. `test@mailinator.com` o `asdf@gmail.com`).
- **Causa Raíz:** Ausencia de validación estricta de dominios y estructura RFC 5322 en el cliente y servicio de autenticación.
- **Corrección Aplicada:** Creación de `GoogleAuthService.validateGoogleEmail()`, incorporando lista negra de dominios temporales, verificación de longitud mínima y reglas de usuario para cuentas reales de Google.
- **Estado:** ✅ CERRADO / VERIFICADO.

---

## 5. RESUMEN DE COBERTURA Y CONCLUSIÓN

```
======================================================================
  RESUMEN FINAL DE INTEGRACIÓN: 9/9 PRUEBAS EXITOSAS (100.0%)
======================================================================
  [PASSED] IT-01 - Autenticación Google Real
  [PASSED] IT-02 - Registro local con Hash SHA-256
  [PASSED] IT-03 - Validación e inserción de lecturas
  [PASSED] IT-04 - Generación de alertas críticas
  [PASSED] IT-05 - Transición y control de ventilación
  [PASSED] IT-06 - Auditoría y trazabilidad
  [PASSED] IT-07 - Control de respaldo y Checksum SHA-256
  [PASSED] IT-08 - Resolución de alerta activa
  [PASSED] IT-09 - Motor de consulta Chatbot
======================================================================
```

**Dictamen de Calidad:**
Los defectos encontrados fueron completamente remediados y verificados. La interacción entre la base de datos PostgreSQL, la capa de autenticación, el sistema de alertas, la ventilación y el motor del Chatbot cumple con los criterios de aceptación para el **VII Semestre**.
