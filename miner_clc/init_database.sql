-- Script de Inicialización y Mejora de Base de Datos - Miner CLC
-- Ejecutar como usuario postgres o administrador
-- NOTA: Adaptado al esquema existente

\c miner_clc

-- Las tablas ya existen, añadir columnas si faltan

-- Tabla usuarios: agregar columnas faltantes si es necesario
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS email VARCHAR(255);
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT NOW();
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS ultimo_acceso TIMESTAMP;
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS google_id VARCHAR(255);
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS auth_provider VARCHAR(50) DEFAULT 'local';
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS foto_url TEXT;
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS email_verificado BOOLEAN DEFAULT FALSE;

-- Tabla lecturas_gases: agregar columnas faltantes
ALTER TABLE lecturas_gases ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT NOW();

-- Tabla ventilacion: agregar columna actualizado_en si no existe
ALTER TABLE ventilacion ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT NOW();

-- Tabla alertas: agregar columnas faltantes
ALTER TABLE alertas ADD COLUMN IF NOT EXISTS nivel VARCHAR(50);
ALTER TABLE alertas ADD COLUMN IF NOT EXISTS resolved_at TIMESTAMP;
ALTER TABLE alertas ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT NOW();

-- Actualizar registros existentes: asignar 'resuelta' = resolved en alertas
UPDATE alertas SET resuelta = COALESCE(resuelta, FALSE) WHERE resuelta IS NULL;

-- Crear índices si no existen (para datos existentes)
CREATE INDEX IF NOT EXISTS idx_lecturas_gases_zona_id ON lecturas_gases(zona_id);
CREATE INDEX IF NOT EXISTS idx_lecturas_gases_registrado_en ON lecturas_gases(registrado_en);
CREATE INDEX IF NOT EXISTS idx_lecturas_gases_zona_registrado ON lecturas_gases(zona_id, registrado_en);
CREATE INDEX IF NOT EXISTS idx_alertas_zona_id ON alertas(zona_id);
CREATE INDEX IF NOT EXISTS idx_alertas_resuelta ON alertas(resuelta);
CREATE INDEX IF NOT EXISTS idx_alertas_creado_en ON alertas(creado_en);
CREATE INDEX IF NOT EXISTS idx_ventilacion_zona_id ON ventilacion(zona_id);
CREATE INDEX IF NOT EXISTS idx_usuarios_usuario ON usuarios(usuario);
CREATE INDEX IF NOT EXISTS idx_alertas_tipo ON alertas(tipo);

-- Función para actualizar updated_at automáticamente
CREATE OR REPLACE FUNCTION actualizar_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger para usuarios (si no existe)
DROP TRIGGER IF EXISTS trigger_usuarios_updated_at ON usuarios;
CREATE TRIGGER trigger_usuarios_updated_at
    BEFORE UPDATE ON usuarios
    FOR EACH ROW
    EXECUTE FUNCTION actualizar_updated_at();

-- Función y trigger para ventilación actualizando actualizado_en
CREATE OR REPLACE FUNCTION actualizar_actualizado_en()
RETURNS TRIGGER AS $$
BEGIN
    NEW.actualizado_en = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_ventilacion_updated_at ON ventilacion;
DROP TRIGGER IF EXISTS trigger_ventilacion_actualizado ON ventilacion;
CREATE TRIGGER trigger_ventilacion_actualizado
    BEFORE UPDATE ON ventilacion
    FOR EACH ROW
    EXECUTE FUNCTION actualizar_actualizado_en();

-- Vista para estadísticas de gases por zona (última hora)
DROP VIEW IF EXISTS v_estadisticas_gases_ultima_hora;
CREATE VIEW v_estadisticas_gases_ultima_hora AS
SELECT 
    zona_id,
    COUNT(*) as cantidad_lecturas,
    AVG(co) as co_promedio,
    MAX(co) as co_maximo,
    MIN(co) as co_minimo,
    AVG(o2) as o2_promedio,
    AVG(co2) as co2_promedio,
    AVG(ch4) as ch4_promedio,
    AVG(h2s) as h2s_promedio,
    AVG(temperatura) as temperatura_promedio,
    NOW() - MAX(registrado_en) as tiempo_desde_ultima_lectura
FROM lecturas_gases
WHERE registrado_en > NOW() - INTERVAL '1 hour'
GROUP BY zona_id;

-- Vista para alertas activas
DROP VIEW IF EXISTS v_alertas_activas;
CREATE VIEW v_alertas_activas AS
SELECT 
    id, zona_id, mensaje, tipo, nivel,
    creado_en, resolved_at, resuelta,
    (NOW() - creado_en) as duracion_activa
FROM alertas
WHERE resuelta = FALSE
ORDER BY creado_en DESC;

-- Vista para mapeo de zonas
DROP VIEW IF EXISTS v_zonas;
CREATE VIEW v_zonas AS
SELECT 
    id as zona_id,
    'Norte - Nivel 1' as nombre_zona
FROM usuarios
WHERE id = 1
UNION ALL
SELECT 2, 'Sur - Nivel 2'
UNION ALL
SELECT 3, 'Este - Nivel 3'
UNION ALL
SELECT 4, 'Oeste - Nivel 1'
UNION ALL
SELECT 5, 'Central - Nivel 2';

-- Tabla de auditoría y logs de sistema (Anexo A)
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

-- Tabla de historial de respaldos de datos (Anexo A)
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

-- Permisos
GRANT USAGE ON SCHEMA public TO postgres;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO postgres;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO postgres;

\echo '✓ Base de datos mejorada correctamente'
\echo '✓ Índices creados'
\echo '✓ Vistas creadas'
\echo '✓ Triggers configurados'
