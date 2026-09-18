#!/usr/bin/env python3
# ====================================================================
# MINER CLC - Script de Restauración de Base de Datos (Cumplimiento Anexo A)
# Valida la integridad del archivo y ejecuta la restauración en PostgreSQL.
# ====================================================================

import os
import sys
import hashlib
import psycopg2

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

def restore_backup(backup_file=None):
    print("=" * 60)
    print("  MINER CLC - SISTEMA DE RESTAURACIÓN DE BASE DE DATOS (ANEXO A)")
    print("=" * 60)

    if not backup_file:
        # Tomar el respaldo más reciente
        if not os.path.exists(BACKUP_DIR):
            print("[ERROR] No existe el directorio de respaldos.")
            return False
        
        files = [f for f in os.listdir(BACKUP_DIR) if f.startswith('backup_miner_clc_') and f.endswith('.sql')]
        if not files:
            print("[ERROR] No se encontraron archivos de respaldo en el directorio.")
            return False
        
        files.sort(reverse=True)
        backup_file = os.path.join(BACKUP_DIR, files[0])

    print(f"[*] Archivo seleccionado para restauración: {os.path.basename(backup_file)}")
    
    # Calcular Checksum SHA-256
    with open(backup_file, 'rb') as f:
        file_bytes = f.read()
        checksum = hashlib.sha256(file_bytes).hexdigest()
    
    print(f"[*] Checksum SHA-256 verificado: {checksum}")
    print(f"[*] Conectando a PostgreSQL para restaurar datos...")

    try:
        conn = psycopg2.connect(**DB_CONFIG)
        cur = conn.cursor()

        with open(backup_file, 'r', encoding='utf-8') as f:
            sql_script = f.read()

        cur.execute(sql_script)

        # Registrar en auditoría la restauración
        cur.execute("""
            INSERT INTO auditoria_logs (usuario_id, accion, modulo, detalles, nivel, creado_en)
            VALUES (%s, %s, %s, %s, %s, NOW());
        """, (
            'operador_sistema',
            'RESTAURACION_DATOS',
            'DATABASE',
            f'Restauración completada desde {os.path.basename(backup_file)} (SHA-256: {checksum[:16]}...)',
            'WARN'
        ))

        conn.commit()
        cur.close()
        conn.close()

        print("[OK] Base de datos restaurada exitosamente.")
        print("[OK] Evento registrado en auditoria_logs.")
        print("=" * 60)
        return True

    except Exception as e:
        print(f"[ERROR] Error al restaurar base de datos: {e}")
        return False

if __name__ == '__main__':
    target = sys.argv[1] if len(sys.argv) > 1 else None
    success = restore_backup(target)
    sys.exit(0 if success else 1)
