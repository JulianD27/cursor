#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
╔══════════════════════════════════════════════════════════════════╗
║        MINER CLC — Demonio de Notificaciones Push / SMS          ║
║                                                                  ║
║  Monitorea la base de datos PostgreSQL en tiempo real y          ║
║  despacha alertas críticas de gases (CH4, CO, O2, H2S)           ║
║  directamente al teléfono del ingeniero vía Telegram / Twilio.   ║
╚══════════════════════════════════════════════════════════════════╝
"""

import os
import sys
import time
import json
import urllib.request
import urllib.parse
from datetime import datetime
import psycopg2

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

CONFIG_FILE = "notification_settings.json"

DB_CONFIG = {
    "host": "localhost",
    "port": 5432,
    "dbname": "miner_clc",
    "user": "postgres",
    "password": "minercl c123",
}

def load_settings():
    default_cfg = {
        "telegramEnabled": True,
        "telegramBotToken": "",
        "telegramChatId": "",
        "twilioEnabled": False,
        "twilioAccountSid": "",
        "twilioAuthToken": "",
        "twilioFromPhone": "",
        "twilioToPhone": "",
        "autoAlertOnDanger": True
    }
    if os.path.exists(CONFIG_FILE):
        try:
            with open(CONFIG_FILE, "r", encoding="utf-8") as f:
                cfg = json.load(f)
                default_cfg.update(cfg)
        except Exception as e:
            print(f"[!] Error leyendo {CONFIG_FILE}: {e}")
    return default_cfg

def send_telegram_alert(token, chat_id, zone, gas_msg, level):
    if not token or not chat_id:
        print("[-] Telegram no configurado (Token o Chat ID vacíos).")
        return False

    now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    is_danger = "danger" in level.lower() or "peligro" in level.lower()
    header = "🚨 *ALERTA CRÍTICA DE MINA - MINER CLC* 🚨" if is_danger else "⚠️ *ADVERTENCIA DE GASES*"

    text = f"""{header}
━━━━━━━━━━━━━━━━━━━━━━━━━━
📍 *Zona Afectada:* `{zone}`
⚡ *Nivel de Severidad:* *{level.upper()}*
💨 *Detalle de Gases:* `{gas_msg}`
⏰ *Fecha/Hora:* `{now_str}`
━━━━━━━━━━━━━━━━━━━━━━━━━━
🚨 *Protocolo Operativo Sugerido:*
• EVACUAR PERSONAL DE LA GALERÍA.
• Encender ventilación forzada al 100%.
• Notificar a brigada de seguridad de turno.
"""

    url = f"https://api.telegram.org/bot{token}/sendMessage"
    payload = {
        "chat_id": chat_id,
        "text": text,
        "parse_mode": "Markdown"
    }
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"})

    try:
        with urllib.request.urlopen(req, timeout=10) as response:
            res_json = json.loads(response.read().decode("utf-8"))
            if res_json.get("ok"):
                print(f"[+] Alerta Telegram entregada exitosamente al chat {chat_id}")
                return True
            else:
                print(f"[-] Telegram respondió: {res_json}")
                return False
    except Exception as e:
        print(f"[!] Excepción conectando con Telegram API: {e}")
        return False

def run_dispatcher():
    print("=" * 65)
    print("  MINER CLC - Demonio de Notificaciones Push / SMS Activo")
    print("=" * 65)

    dispatched_alert_ids = set()

    while True:
        cfg = load_settings()
        if not cfg.get("autoAlertOnDanger", True):
            time.sleep(5)
            continue

        try:
            conn = psycopg2.connect(**DB_CONFIG)
            conn.autocommit = True
            cur = conn.cursor()

            cur.execute("""
                SELECT a.id, a.mensaje, a.tipo, COALESCE(z.nombre, 'Zona Desconocida') as zona, a.creado_en
                FROM alertas a
                LEFT JOIN zonas z ON a.zona_id = z.id
                WHERE a.tipo IN ('danger', 'high', 'critico')
                  AND a.resuelta = FALSE
                  AND a.creado_en > NOW() - INTERVAL '30 minutes'
                ORDER BY a.id DESC
                LIMIT 5;
            """)

            alerts = cur.fetchall()
            cur.close()
            conn.close()

            for alert_id, msg, level, zone, dt in alerts:
                if alert_id not in dispatched_alert_ids:
                    print(f"\n[!] Detectada alerta crítica #{alert_id} en {zone}: {msg}")

                    # Despachar Telegram si está activo
                    if cfg.get("telegramEnabled") and cfg.get("telegramBotToken") and cfg.get("telegramChatId"):
                        ok = send_telegram_alert(
                            token=cfg["telegramBotToken"],
                            chat_id=cfg["telegramChatId"],
                            zone=zone,
                            gas_msg=msg,
                            level=level
                        )
                        if ok:
                            dispatched_alert_ids.add(alert_id)
                    else:
                        dispatched_alert_ids.add(alert_id)

        except Exception as e:
            print(f"[!] Error en ciclo de sondeo: {e}")

        time.sleep(4)

if __name__ == "__main__":
    run_dispatcher()
