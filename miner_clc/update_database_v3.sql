-- ====================================================================
-- Script de Migración V3 - MINER CLC
-- Ampliación de Base de Datos para:
-- 1. Soporte de Autenticación con Google Real (OAuth2)
-- 2. Sistema de Logging y Auditoría (Anexo A)
-- 3. Historial y Control de Respaldos de Datos (Anexo A)
-- ====================================================================

\c miner_clc

-- 1. Ampliación de la tabla 'usuarios' para Google OAuth y verificación
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS google_id VARCHAR(255);
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS auth_provider VARCHAR(50) DEFAULT 'local';
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS foto_url TEXT;
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS email_verificado BOOLEAN DEFAULT FALSE;

-- Índice para búsquedas rápidas por google_id y email
CREATE INDEX IF NOT EXISTS idx_usuarios_google_id ON usuarios(google_id);
CREATE INDEX IF NOT EXISTS idx_usuarios_email ON usuarios(email);

-- 2. Tabla de Auditoría y Logging del Sistema (Requerimiento Anexo A)
CREATE TABLE IF NOT EXISTS auditoria_logs (
    id SERIAL PRIMARY KEY,
    usuario_id VARCHAR(100),
    accion VARCHAR(100) NOT NULL,
    modulo VARCHAR(50) NOT NULL,
    detalles TEXT,
    nivel VARCHAR(20) DEFAULT 'INFO',
    ip_origen VARCHAR(45) DEFAULT '127.0.0.1',
    creado_en TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_auditoria_logs_creado_en ON auditoria_logs(creado_en);
CREATE INDEX IF NOT EXISTS idx_auditoria_logs_usuario ON auditoria_logs(usuario_id);
CREATE INDEX IF NOT EXISTS idx_auditoria_logs_modulo ON auditoria_logs(modulo);
CREATE INDEX IF NOT EXISTS idx_auditoria_logs_nivel ON auditoria_logs(nivel);

-- 3. Tabla de Control de Respaldos de Datos (Requerimiento Anexo A)
CREATE TABLE IF NOT EXISTS respaldos_historial (
    id SERIAL PRIMARY KEY,
    nombre_archivo VARCHAR(255) NOT NULL,
    tamano_bytes BIGINT DEFAULT 0,
    checksum_sha256 VARCHAR(64),
    tipo VARCHAR(50) DEFAULT 'COMPLETO',
    usuario VARCHAR(100) DEFAULT 'sistema',
    estado VARCHAR(50) DEFAULT 'EXITOSO',
    detalles TEXT,
    creado_en TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_respaldos_creado_en ON respaldos_historial(creado_en);

-- 4. Registrar evento inicial de migración en la tabla de auditoría
INSERT INTO auditoria_logs (usuario_id, accion, modulo, detalles, nivel)
VALUES ('sistema', 'MIGRACION_V3', 'DATABASE', 'Aplicada ampliación de esquema V3: Google Auth, Auditoría y Respaldos', 'INFO');

\echo '✓ Esquema V3 aplicado exitosamente a miner_clc'
