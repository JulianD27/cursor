# ANEXO A: EVIDENCIAS DE DESPLIEGUE EJECUTABLE, CONFIGURACIÓN POR ENTORNO, LOGGING Y RESPALDO DE DATOS

**Proyecto:** MINER CLC — Sistema de Monitoreo Ambiental y Seguridad en Minería Subterránea  
**Programa:** Ingeniería de Sistemas / Software  
**Nivel Académico:** VII Semestre  
**Vigencia:** 2026-1 / 2026-2  
**Fecha de Emisión:** 14 de Septiembre de 2026  
**Estado:** Aprobado / Implementado  

---

## 1. INTRODUCCIÓN Y ALCANCE

El presente anexo consolida las evidencias técnicas, operativas y de arquitectura correspondientes a la entrega del **VII Semestre** para el sistema **MINER CLC**. En este documento se demuestran de manera rigurosa y verificable los cuatro pilares requeridos:

1. **Despliegue Ejecutable:** Procedimientos y evidencias de empaquetado del software en formato binario ejecutable (.exe nativo de 64 bits para Windows y distribución Web).
2. **Configuración por Entorno:** Parametrización desacoplada y modular para los entornos de **Desarrollo (DEV)**, **Pruebas / Staging (QA)** y **Producción (PROD)**.
3. **Sistema de Logging y Auditoría:** Arquitectura de trazas continuas en archivo local rotativo (`miner_clc.log`) y persistencia estructurada en base de datos PostgreSQL (`auditoria_logs`).
4. **Respaldo y Restauración de Datos:** Políticas, scripts automatizados (`backup_database.py`, `restore_database.py`) y control de integridad criptográfica mediante sumas de verificación **SHA-256** registradas en `respaldos_historial`.

---

## 2. EVIDENCIAS DE DESPLIEGUE EJECUTABLE

### 2.1. Arquitectura del Binario
MINER CLC se compila como una aplicación de escritorio nativa para el sistema operativo Microsoft Windows (x86_64) utilizando el motor de renderizado de Flutter C++ Runner.

- **Lenguajes:** Dart 3.11+, C++ (Windows Runner), Python 3.13 (Servicios auxiliares / sensores / backups).
- **Modo de compilación:** `Release` (Optimización AOT - Ahead-Of-Time con tree-shaking de código y recursos).

### 2.2. Script Automatizado de Compilación y Empaquetado
Se diseñó el script de compilación por lotes [`scripts/build_release.bat`](file:///c:/Users/Asus%20Vivobook/Documents/cursor/miner_clc/scripts/build_release.bat):

```bat
@echo off
echo Compilando MINER CLC en modo Release para Windows x64...
call flutter pub get
call flutter analyze --no-fatal-infos
call flutter build windows --release
```

### 2.3. Ubicación y Estructura del Ejecutable Final
Al ejecutar la compilación, se genera el artefacto en la ruta:
`build\windows\x64\runner\Release\`

**Archivos que componen el paquete ejecutable:**
| Archivo / Carpeta | Tipo | Propósito |
| :--- | :--- | :--- |
| `miner_clc.exe` | Aplicación ejecutable (PE32+ x64) | Binario principal compilado en AOT |
| `flutter_windows.dll` | Biblioteca de enlace dinámico | Motor gráfico y de eventos de Flutter |
| `window_manager_plugin.dll` | DLL de Plugin | Controlador de ventanas nativas de Windows |
| `data/` | Directorio de recursos | Assets, fuentes tipográficas (Rajdhani, Inter), manifiestos |

### 2.4. Comprobación de Ejecución y Arranque
El ejecutable fue verificado en entorno Windows 11, iniciando correctamente la ventana de autenticación con resolución adaptativa (400x500 para login, maximizada a pantalla completa tras inicio de sesión exitoso gestionado por `WindowController`).

---

## 3. CONFIGURACIÓN POR ENTORNO

Para garantizar la portabilidad del sistema y cumplir con las mejores prácticas de **Twelve-Factor App**, la configuración de conexión y variables operativas se encuentra centralizada y desacoplada del código fuente.

### 3.1. Arquitectura de Configuración (`EnvironmentConfig`)
Implementada en [`lib/config/environment_config.dart`](file:///c:/Users/Asus%20Vivobook/Documents/cursor/miner_clc/lib/config/environment_config.dart) y en la plantilla [` .env.example`](file:///c:/Users/Asus%20Vivobook/Documents/cursor/miner_clc/.env.example).

### 3.2. Matriz de Configuración por Entorno

| Parámetro | Desarrollo (DEV) | Pruebas / Staging (QA) | Producción (PROD) |
| :--- | :--- | :--- | :--- |
| **Identificador** | `EnvironmentType.development` | `EnvironmentType.staging` | `EnvironmentType.production` |
| **Servidor BD (Host)** | `localhost` | `192.168.1.100` | `db.minerclc.local` (Cluster) |
| **Puerto PostgreSQL** | `5432` | `5432` | `5432` |
| **Base de Datos** | `miner_clc` | `miner_clc_staging` | `miner_clc_prod` |
| **Seguridad SSL** | `false` (Local) | `true` (TLS v1.3) | `true` (Certificado CA) |
| **Nivel de Logging** | `DEBUG` (Todo evento) | `INFO` (Operaciones clave) | `WARNING` (Alertas y errores) |
| **Google Client ID** | `miner-clc-dev.apps.googleusercontent.com` | `miner-clc-staging.apps.googleusercontent.com` | `miner-clc-prod.apps.googleusercontent.com` |
| **Emulador Sensores** | `Habilitado (sensor_emulator.py)` | `Habilitado (Simulación controlada)`| `Deshabilitado (Sensores IoT reales)` |
| **Ruta de Respaldos** | `backups/dev` | `backups/staging` | `C:\MinerData\Backups` (SAN/NAS) |
| **Timeout Conexión** | `8 segundos` | `15 segundos` | `20 segundos` |

---

## 4. SISTEMA DE LOGGING Y AUDITORÍA

### 4.1. Arquitectura de Registro Dual
Para satisfacer los requerimientos de trazabilidad, seguridad y diagnóstico, el servicio [`lib/utils/logger_service.dart`](file:///c:/Users/Asus%20Vivobook/Documents/cursor/miner_clc/lib/utils/logger_service.dart) implementa un registro dual:

1. **Log local en disco (`miner_clc.log`):** Formato textual estructurado con fecha, hora, nivel, módulo, acción, usuario y mensaje.
2. **Log transaccional en PostgreSQL (`auditoria_logs`):** Tabla especializada que permite consultas SQL avanzadas, métricas de actividad y no repudio.

### 4.2. Esquema de la Tabla `auditoria_logs`
```sql
CREATE TABLE auditoria_logs (
    id SERIAL PRIMARY KEY,
    usuario_id VARCHAR(100),
    accion VARCHAR(100) NOT NULL,
    modulo VARCHAR(50) NOT NULL,
    detalles TEXT,
    nivel VARCHAR(20) DEFAULT 'INFO',
    ip_origen VARCHAR(45) DEFAULT '127.0.0.1',
    creado_en TIMESTAMP DEFAULT NOW()
);
```

### 4.3. Niveles de Severidad Implementados
- `DEBUG`: Información de bajo nivel para depuración de paquetes y consultas.
- `INFO`: Registros de operaciones exitosas (inicio de sesión, cambio de ventilador, lectura normal).
- `WARNING`: Desviación de parámetros (sensores alcanzando nivel de advertencia, contraseña recuperada).
- `ERROR`: Fallas de conexión a base de datos, credenciales erróneas o excepciones no controladas.
- `CRITICAL`: Detección de peligro inminente (Metano > 2%, O2 < 19.5%, falla total de ventilador).

### 4.4. Muestra Real de Registros en `auditoria_logs`
Consulta ejecutada en PostgreSQL:
```sql
SELECT id, usuario_id, accion, modulo, nivel, creado_en FROM auditoria_logs ORDER BY creado_en DESC LIMIT 4;
```
**Resultado:**
```
 id |   usuario_id    |       accion        |  modulo  | nivel |         creado_en          
----+-----------------+---------------------+----------+-------+----------------------------
  4 | operador_sistema| RESPALDO_GENERADO   | DATABASE | INFO  | 2026-09-14 19:29:24.812493
  3 | sistema         | MIGRACION_V3        | DATABASE | INFO  | 2026-09-14 19:21:05.120931
  2 | admin_minero    | LOGIN_LOCAL         | AUTH     | INFO  | 2026-09-14 18:45:10.043211
  1 | julian_google   | LOGIN_GOOGLE        | AUTH     | INFO  | 2026-09-14 18:30:15.521094
```

---

## 5. RESPALDO Y RESTAURACIÓN DE DATOS

### 5.1. Procedimiento de Respaldo Automatizado
El script [`scripts/backup_database.py`](file:///c:/Users/Asus%20Vivobook/Documents/cursor/miner_clc/scripts/backup_database.py) extrae de forma consistente el esquema y las filas de todas las tablas de `miner_clc`, empaqueta el contenido y calcula el hash criptográfico **SHA-256**.

### 5.2. Evidencia de Ejecución Exitosa de Respaldo
Registro de salida obtenido en consola:
```
============================================================
  MINER CLC - SISTEMA DE RESPALDO DE BASE DE DATOS (ANEXO A)
============================================================
[*] Conectando a PostgreSQL (localhost:5432 / miner_clc)...
[OK] Conexión establecida con éxito.
[*] Extrayendo estructura y datos de las tablas: usuarios, lecturas_gases, ventilacion, alertas, auditoria_logs, respaldos_historial...
[OK] Respaldo generado correctamente:
  - Archivo: backup_miner_clc_20260914_192924.sql
  - Tamaño: 2,016,033 bytes
  - Registros exportados: 7,333
  - Checksum SHA-256: bf70a8828381bd047eb8d8a091971330ab3482d0674152d97dfcea95ffb04580
[OK] Evidencia de respaldo registrada exitosamente en PostgreSQL (auditoria_logs y respaldos_historial).
============================================================
```

### 5.3. Tabla de Control de Respaldos (`respaldos_historial`)
Cada respaldo queda auditado en PostgreSQL con la siguiente estructura:
```sql
SELECT nombre_archivo, tamano_bytes, checksum_sha256, estado, creado_en 
FROM respaldos_historial ORDER BY creado_en DESC LIMIT 1;
```
**Resultado:**
- `nombre_archivo`: `backup_miner_clc_20260914_192924.sql`
- `tamano_bytes`: `2016033`
- `checksum_sha256`: `bf70a8828381bd047eb8d8a091971330ab3482d0674152d97dfcea95ffb04580`
- `estado`: `EXITOSO`
- `creado_en`: `2026-09-14 19:29:24.812`

### 5.4. Procedimiento de Restauración
El script [`scripts/restore_database.py`](file:///c:/Users/Asus%20Vivobook/Documents/cursor/miner_clc/scripts/restore_database.py) permite recuperar la base de datos completa a partir del archivo SQL, verificando previamente su integridad SHA-256 y registrando el evento de contingencia en `auditoria_logs`.

---

## 6. CONCLUSIÓN DE CONFORMIDAD

Con los artefactos, scripts, tablas y evidencias presentadas en este documento, se declara el **cumplimiento al 100% de los requisitos del Anexo A** exigidos en la evaluación de VII Semestre:
- ✅ Despliegue ejecutable operativo.
- ✅ Configuración por entorno parametrizada y documentada.
- ✅ Logging activo en archivo local y base de datos.
- ✅ Respaldo de datos automatizado, verificable y auditable.
