#!/usr/bin/env python3
# ====================================================================
# MINER CLC - Script de Respaldo de Base de Datos (Cumplimiento Anexo A)
# Realiza volcado estructurado de PostgreSQL, calcula hash SHA-256
# y registra la evidencia en la tabla respaldos_historial.
# ====================================================================

import os
import sys
import datetime
import hashlib
import psycopg2
from psycopg2 import sql

# Configurar encoding UTF-8 en stdout para terminales Windows
if sys.stdout.encoding != 'utf-8':
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass

DB_CONFIG = {
    'host': 'localhost',
    'port': 5432,
    'dbname': 'miner_clc',
    'user': 'postgres',
    'password': 'minercl c123'
}

BACKUP_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'backups')

def create_backup():
    print("=" * 60)
    print("  MINER CLC - SISTEMA DE RESPALDO DE BASE DE DATOS (ANEXO A)")
    print("=" * 60)

    if not os.path.exists(BACKUP_DIR):
        os.makedirs(BACKUP_DIR)
        print(f"[OK] Directorio de respaldos creado: {BACKUP_DIR}")

    timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_filename = f"backup_miner_clc_{timestamp}.sql"
    backup_filepath = os.path.join(BACKUP_DIR, backup_filename)

    print(f"[*] Conectando a PostgreSQL ({DB_CONFIG['host']}:{DB_CONFIG['port']} / {DB_CONFIG['dbname']})...")
    
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        cur = conn.cursor()
        print("[OK] Conexión establecida con éxito.")

        # Tablas a respaldar
        tables = ['usuarios', 'lecturas_gases', 'ventilacion', 'alertas', 'auditoria_logs', 'respaldos_historial']
        
        print(f"[*] Extrayendo estructura y datos de las tablas: {', '.join(tables)}...")
        
        with open(backup_filepath, 'w', encoding='utf-8') as f:
            f.write(f"-- ========================================================\n")
            f.write(f"-- RESPALDO AUTOMÁTICO MINER CLC - BASE DE DATOS\n")
            f.write(f"-- Fecha de generación: {datetime.datetime.now().isoformat()}\n")
            f.write(f"-- Entorno: Producción / Desarrollo\n")
            f.write(f"-- ========================================================\n\n")

            total_records = 0

            for table in tables:
                f.write(f"\n-- Tabla: {table}\n")
                
                # Obtener columnas
                cur.execute(f"""
                    SELECT column_name, data_type 
                    FROM information_schema.columns 
                    WHERE table_schema='public' AND table_name='{table}'
                    ORDER BY ordinal_position;
                """)
                cols = [r[0] for r in cur.fetchall()]
                
                if not cols:
                    continue

                col_str = ", ".join(cols)
                
                # Obtener registros
                cur.execute(f"SELECT {col_str} FROM {table};")
                rows = cur.fetchall()
                total_records += len(rows)

                f.write(f"-- Registros encontrados: {len(rows)}\n")
                for r in rows:
                    vals = []
                    for val in r:
                        if val is None:
                            vals.append("NULL")
                        elif isinstance(val, (int, float)):
                            vals.append(str(val))
                        elif isinstance(val, bool):
                            vals.append("TRUE" if val else "FALSE")
                        elif isinstance(val, (datetime.date, datetime.datetime)):
                            vals.append(f"'{val.isoformat()}'")
                        else:
                            clean_str = str(val).replace("'", "''")
                            vals.append(f"'{clean_str}'")
                    
                    f.write(f"INSERT INTO {table} ({col_str}) VALUES ({', '.join(vals)}) ON CONFLICT DO NOTHING;\n")

        # Calcular Checksum SHA-256
        with open(backup_filepath, 'rb') as f:
            file_bytes = f.read()
            checksum = hashlib.sha256(file_bytes).hexdigest()

        file_size = os.path.getsize(backup_filepath)

        print(f"[OK] Respaldo generado correctamente:")
        print(f"  - Archivo: {backup_filename}")
        print(f"  - Tamaño: {file_size:,} bytes")
        print(f"  - Registros exportados: {total_records}")
        print(f"  - Checksum SHA-256: {checksum}")

        # Registrar respaldo en la tabla respaldos_historial
        cur.execute("""
            INSERT INTO respaldos_historial (nombre_archivo, tamano_bytes, checksum_sha256, tipo, usuario, estado, detalles, creado_en)
            VALUES (%s, %s, %s, %s, %s, %s, %s, NOW());
        """, (
            backup_filename,
            file_size,
            checksum,
            'COMPLETO_SQL',
            'operador_sistema',
            'EXITOSO',
            f'Total tablas: {len(tables)}, total registros: {total_records}'
        ))

        # Registrar en auditoría
        cur.execute("""
            INSERT INTO auditoria_logs (usuario_id, accion, modulo, detalles, nivel, creado_en)
            VALUES (%s, %s, %s, %s, %s, NOW());
        """, (
            'operador_sistema',
            'RESPALDO_GENERADO',
            'DATABASE',
            f'Generado respaldo {backup_filename} ({file_size} bytes, SHA-256: {checksum[:16]}...)',
            'INFO'
        ))

        conn.commit()
        cur.close()
        conn.close()

        print("[OK] Evidencia de respaldo registrada exitosamente en PostgreSQL (auditoria_logs y respaldos_historial).")
        print("=" * 60)
        return True, backup_filepath, checksum

    except Exception as e:
        print(f"✗ ERROR al generar respaldo: {e}")
        return False, None, None

if __name__ == '__main__':
    success, path, chk = create_backup()
    sys.exit(0 if success else 1)
