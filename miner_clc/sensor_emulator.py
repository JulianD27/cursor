"""
╔══════════════════════════════════════════════════════════╗
║         MINER CLC — Emulador de Sensores v4.0           ║
║                                                          ║
║  LÓGICA CORREGIDA:                                       ║
║  • Ventilador ON 100% → baja gases RÁPIDO               ║
║  • Ventilador OFF     → gases suben gradualmente        ║
║  • Ventilador AUTO    → respuesta inmediata              ║
║  • Arranque siempre en valores SEGUROS                   ║
║  • Alertas por zona con control de frecuencia           ║
╚══════════════════════════════════════════════════════════╝

Requisitos:
    pip install psycopg2-binary colorama
"""

import time, random, threading
import psycopg2
from datetime import datetime
from colorama import Fore, Style, init
init(autoreset=True)

# ── BD ───────────────────────────────────────
DB_CONFIG = {
    "host": "localhost", "port": 5432,
    "dbname": "miner_clc", "user": "postgres", "password": "minercl c123",
}

ZONAS = [
    "Norte - Nivel 1", "Sur - Nivel 2", "Este - Nivel 3",
    "Oeste - Nivel 1", "Central - Nivel 2",
]

# ── UMBRALES ──────────────────────────────────
# (warn, danger)
U = {
    "co":          (25.0,  50.0),
    "o2":          (19.5,  18.0),   # inverso
    "co2":         (1.0,   2.0),
    "ch4":         (1.0,   2.0),
    "h2s":         (10.0,  20.0),
    "temperatura": (35.0,  40.0),
}

# ── VALORES SEGUROS OBJETIVO ──────────────────
SEGURO = {
    "Norte - Nivel 1":   {"co":8.0,  "o2":20.8, "co2":0.04, "ch4":0.4, "h2s":2.0, "temperatura":23.0},
    "Sur - Nivel 2":     {"co":10.0, "o2":20.6, "co2":0.05, "ch4":0.5, "h2s":2.5, "temperatura":24.0},
    "Este - Nivel 3":    {"co":9.0,  "o2":20.7, "co2":0.04, "ch4":0.4, "h2s":2.0, "temperatura":23.5},
    "Oeste - Nivel 1":   {"co":7.0,  "o2":20.9, "co2":0.03, "ch4":0.3, "h2s":1.5, "temperatura":22.0},
    "Central - Nivel 2": {"co":9.0,  "o2":20.7, "co2":0.05, "ch4":0.5, "h2s":2.5, "temperatura":24.0},
}

# ── ESTADO DINÁMICO (arranca seguro) ──────────
zona_estado = {z: dict(SEGURO[z]) for z in ZONAS}

control = {
    "corriendo": False,
    "intervalo": 5,
    "manual":    {z: None for z in ZONAS},
}

_ultima_alerta = {z: datetime.min for z in ZONAS}

# ─────────────────────────────────────────────
def conectar():
    try:
        c = psycopg2.connect(**DB_CONFIG)
        c.autocommit = False
        print(Fore.GREEN + "✅ Conectado a PostgreSQL")
        return c
    except Exception as e:
        print(Fore.RED + f"❌ {e}")
        return None

def leer_ventilacion(conn):
    try:
        cur = conn.cursor()
        cur.execute("SELECT zona, estado, velocidad, modo FROM ventilacion")
        rows = cur.fetchall()
        cur.close()
        return {
            z: {"estado": e or "off", "velocidad": int(v or 0), "modo": m or "manual"}
            for z, e, v, m in rows
        }
    except Exception as e:
        print(Fore.RED + f"⚠️ Error leyendo ventilación: {e}")
        try: conn.rollback()
        except: pass
        return {}

# ─────────────────────────────────────────────
#  NÚCLEO: SIMULAR UN CICLO POR ZONA
# ─────────────────────────────────────────────
def simular_ciclo(zona, vent_info):
    """
    Actualiza zona_estado[zona] según ventilación.
    Retorna (valores_nuevos, factor_ventilacion).
    """
    v   = zona_estado[zona]
    seg = SEGURO[zona]
    vnt = vent_info.get(zona, {"estado":"off","velocidad":0,"modo":"manual"})

    est_v = vnt["estado"]
    vel   = vnt["velocidad"]
    modo  = vnt["modo"]

    # ── FACTOR DE VENTILACIÓN (0.0 → 1.0) ──────
    if est_v == "off":
        factor = 0.0
    elif modo == "auto" or est_v == "auto":
        # AUTO: reacciona al nivel de contaminación actual
        peligro = max(
            v["co"]  / 50.0,
            (20.9 - v["o2"]) / 6.9,
            v["co2"] / 2.0,
            v["ch4"] / 2.0,
            v["h2s"] / 20.0,
        )
        factor = min(1.0, 0.5 + peligro * 0.5)
    else:
        factor = vel / 100.0

    r = lambda mag: random.uniform(-mag, mag)  # ruido

    if factor >= 0.01:
        # ── CON VENTILACIÓN: mover hacia valores seguros ──
        # Cuanto mayor el factor, más rápido se normaliza.
        # Con factor=1.0 llega al objetivo en ~4-5 ciclos.
        paso = factor * 0.55   # 55% del camino por ciclo con factor=1

        def ir(actual, objetivo, max_bajada, max_subida=None):
            diff = objetivo - actual
            if max_subida is None: max_subida = max_bajada
            ajuste = diff * paso
            # Limitar paso máximo por ciclo para que sea gradual
            if diff < 0:
                ajuste = max(ajuste, -max_bajada)
            else:
                ajuste = min(ajuste, max_subida)
            return actual + ajuste

        v["co"]          = ir(v["co"],  seg["co"],  12.0)
        v["o2"]          = ir(v["o2"],  seg["o2"],  0.8)
        v["co2"]         = ir(v["co2"], seg["co2"], 0.4)
        v["ch4"]         = ir(v["ch4"], seg["ch4"], 0.4)
        v["h2s"]         = ir(v["h2s"], seg["h2s"], 6.0)
        v["temperatura"] = ir(v["temperatura"], seg["temperatura"], 3.0)

    else:
        # ── SIN VENTILACIÓN: acumulación progresiva ──
        # Aumenta cada ciclo hasta límites físicos
        v["co"]          += r(0.5) + random.uniform(1.5, 3.5)
        v["o2"]          -= r(0.03) + random.uniform(0.08, 0.18)
        v["co2"]         += r(0.02) + random.uniform(0.04, 0.10)
        v["ch4"]         += r(0.02) + random.uniform(0.03, 0.08)
        v["h2s"]         += r(0.2)  + random.uniform(0.5,  1.5)
        v["temperatura"] += r(0.2)  + random.uniform(0.5,  1.2)

    # ── RUIDO SENSOR (siempre presente) ──────────
    v["co"]          += r(0.3)
    v["o2"]          += r(0.02)
    v["co2"]         += r(0.003)
    v["ch4"]         += r(0.01)
    v["h2s"]         += r(0.1)
    v["temperatura"] += r(0.08)

    # ── APLICAR MANUAL SI ACTIVO ─────────────────
    if control["manual"][zona]:
        v.update(control["manual"][zona])

    # ── CLAMP ────────────────────────────────────
    v["co"]          = max(0.0,  min(100.0, round(v["co"],  1)))
    v["o2"]          = max(14.0, min(21.0,  round(v["o2"],  2)))
    v["co2"]         = max(0.0,  min(6.0,   round(v["co2"], 3)))
    v["ch4"]         = max(0.0,  min(6.0,   round(v["ch4"], 3)))
    v["h2s"]         = max(0.0,  min(50.0,  round(v["h2s"], 1)))
    v["temperatura"] = max(14.0, min(60.0,  round(v["temperatura"], 1)))

    return dict(v), factor

# ─────────────────────────────────────────────
def estado_gas(v):
    if (v["co"] >= U["co"][1] or v["o2"] <= U["o2"][1] or
        v["co2"] >= U["co2"][1] or v["ch4"] >= U["ch4"][1] or
        v["h2s"] >= U["h2s"][1] or v["temperatura"] >= U["temperatura"][1]):
        return "danger"
    if (v["co"] >= U["co"][0] or v["o2"] <= U["o2"][0] or
        v["co2"] >= U["co2"][0] or v["ch4"] >= U["ch4"][0] or
        v["h2s"] >= U["h2s"][0] or v["temperatura"] >= U["temperatura"][0]):
        return "warn"
    return "normal"

def insertar(conn, zona, v, est):
    try:
        cur = conn.cursor()
        cur.execute("""
            INSERT INTO lecturas_gases
              (zona,co,o2,co2,ch4,h2s,temperatura,estado,registrado_en)
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s)
        """, (zona,v["co"],v["o2"],v["co2"],v["ch4"],
              v["h2s"],v["temperatura"],est,datetime.now()))
        conn.commit(); cur.close()
        return True
    except Exception as e:
        print(Fore.RED+f"❌ {zona}: {e}")
        try: conn.rollback()
        except: pass
        return False

def alerta(conn, zona, v, est):
    if est not in ("warn","danger"): return
    ahora = datetime.now()
    if (ahora - _ultima_alerta[zona]).total_seconds() < 60: return
    _ultima_alerta[zona] = ahora
    msgs = []
    if v["co"]  >= U["co"][0]:  msgs.append(f"CO:{v['co']:.1f}ppm")
    if v["o2"]  <= U["o2"][0]:  msgs.append(f"O₂:{v['o2']:.2f}%")
    if v["co2"] >= U["co2"][0]: msgs.append(f"CO₂:{v['co2']:.3f}%")
    if v["ch4"] >= U["ch4"][0]: msgs.append(f"CH₄:{v['ch4']:.3f}%LEL")
    if v["h2s"] >= U["h2s"][0]: msgs.append(f"H₂S:{v['h2s']:.1f}ppm")
    if v["temperatura"] >= U["temperatura"][0]:
        msgs.append(f"Temp:{v['temperatura']:.1f}°C")
    if not msgs: return
    try:
        cur = conn.cursor()
        cur.execute("""
            INSERT INTO alertas (mensaje,tipo,zona,resuelta)
            VALUES (%s,%s,%s,FALSE)
        """, (" | ".join(msgs), est, zona))
        conn.commit(); cur.close()
        c = Fore.RED if est=="danger" else Fore.YELLOW
        print(c+f"  🚨 ALERTA [{zona}]: {' | '.join(msgs)}")
    except Exception as e:
        print(Fore.RED+f"❌ alerta: {e}")
        try: conn.rollback()
        except: pass

COLOR = {"normal":Fore.GREEN,"warn":Fore.YELLOW,"danger":Fore.RED}
SIM   = {"on":"💨","off":"🔴","auto":"🤖"}

def imprimir(zona, v, est, vnt, factor):
    c   = COLOR.get(est, Fore.WHITE)
    ts  = datetime.now().strftime("%H:%M:%S")
    s   = SIM.get(vnt.get("estado","off"),"❓")
    vel = vnt.get("velocidad",0)
    m   = "[M]" if control["manual"][zona] else "   "
    print(f"{Fore.CYAN}[{ts}] "
          f"{Fore.MAGENTA}{zona[:18]:<18} "
          f"{s}V:{vel:>3}% f={factor:.2f} {m} "
          f"CO:{c}{v['co']:>6.1f}{Style.RESET_ALL} "
          f"O₂:{Fore.CYAN}{v['o2']:>5.2f}{Style.RESET_ALL} "
          f"CO₂:{v['co2']:>6.3f} "
          f"H₂S:{c}{v['h2s']:>5.1f}{Style.RESET_ALL} "
          f"🌡{v['temperatura']:>5.1f} "
          f"→{c}{est.upper()}{Style.RESET_ALL}")

# ─────────────────────────────────────────────
def hilo_emulador(conn):
    print(Fore.GREEN +
          f"\n▶  Emulando {len(ZONAS)} zonas · {control['intervalo']}s/ciclo"
          f"\n   Todas arrancan en valores SEGUROS\n")
    ciclo = 0
    while control["corriendo"]:
        ciclo += 1
        vent_info = leer_ventilacion(conn)
        print(f"\n{Fore.WHITE}── Ciclo {ciclo} ──────────────────────────────────────────{Style.RESET_ALL}")
        for zona in ZONAS:
            vals, factor = simular_ciclo(zona, vent_info)
            est = estado_gas(vals)
            if insertar(conn, zona, vals, est):
                imprimir(zona, vals, est, vent_info.get(zona,{}), factor)
                alerta(conn, zona, vals, est)
        time.sleep(control["intervalo"])
    print(Fore.YELLOW+"\n⏹  Emulador detenido.")

# ─────────────────────────────────────────────
def menu(conn):
    hilo = None
    while True:
        run = (Fore.GREEN+"▶ CORRIENDO") if control["corriendo"] else (Fore.RED+"⏹ DETENIDO")
        manuales = [z for z in ZONAS if control["manual"][z]]
        print(f"""
{Fore.CYAN}╔══════════════════════════════════════════╗
║    MINER CLC — Emulador v4.0             ║
╚══════════════════════════════════════════╝{Style.RESET_ALL}
  Estado   : {run}{Style.RESET_ALL}
  Intervalo: {control['intervalo']}s
  Manuales : {Fore.YELLOW}{', '.join(manuales) if manuales else 'ninguna'}{Style.RESET_ALL}

  [1] Iniciar / Detener
  [2] Editar valores manuales de una zona
  [3] Quitar modo manual (volver a simulación)
  [4] Resetear zona(s) a valores seguros
  [5] Cambiar intervalo
  [6] Lectura única ahora
  [7] Ver ventilación en BD
  [0] Salir
""")
        op = input("  Opción: ").strip()

        if op == "1":
            if control["corriendo"]:
                control["corriendo"] = False
                if hilo: hilo.join(timeout=control["intervalo"]+3)
            else:
                control["corriendo"] = True
                hilo = threading.Thread(target=hilo_emulador, args=(conn,), daemon=True)
                hilo.start()

        elif op == "2":
            for i,z in enumerate(ZONAS):
                m = f" {Fore.YELLOW}[M]{Style.RESET_ALL}" if control["manual"][z] else ""
                print(f"  [{i+1}] {z}{m}")
            sel = input("  Zona: ").strip()
            if sel.isdigit() and 1<=int(sel)<=len(ZONAS):
                zona = ZONAS[int(sel)-1]
                base = control["manual"][zona] or dict(zona_estado[zona])
                print(f"\n  {Fore.CYAN}Editar — {zona}{Style.RESET_ALL} (Enter=mantener)\n")
                campos = [
                    ("co","CO (ppm)",0,100),("o2","O₂ (%)",14,21),
                    ("co2","CO₂ (%)",0,6),("ch4","CH₄ (%LEL)",0,6),
                    ("h2s","H₂S (ppm)",0,50),("temperatura","Temp (°C)",14,60),
                ]
                nuevo = {}
                for k,lbl,mn,mx in campos:
                    act = base.get(k,0)
                    raw = input(f"  {lbl} [{mn}-{mx}] (actual {act}): ").strip()
                    if raw:
                        try:
                            val=float(raw)
                            nuevo[k] = round(max(mn,min(mx,val)),3)
                            print(Fore.GREEN+f"  ✅ {lbl}={nuevo[k]}")
                        except: nuevo[k]=act
                    else: nuevo[k]=act
                control["manual"][zona]=nuevo
                zona_estado[zona].update(nuevo)
                print(Fore.GREEN+f"  ✅ {zona} → MANUAL")

        elif op == "3":
            ml=[z for z in ZONAS if control["manual"][z]]
            if not ml: print(Fore.YELLOW+"  Ninguna en manual.")
            else:
                for i,z in enumerate(ml): print(f"  [{i+1}] {z}")
                sel=input("  Zona: ").strip()
                if sel.isdigit() and 1<=int(sel)<=len(ml):
                    z=ml[int(sel)-1]; control["manual"][z]=None
                    print(Fore.GREEN+f"  {z} → simulación")

        elif op == "4":
            for i,z in enumerate(ZONAS): print(f"  [{i+1}] {z}")
            print(f"  [6] TODAS")
            sel=input("  Zona: ").strip()
            if sel=="6":
                for z in ZONAS: zona_estado[z]=dict(SEGURO[z]); control["manual"][z]=None
                print(Fore.GREEN+"  ✅ Todas reseteadas")
            elif sel.isdigit() and 1<=int(sel)<=len(ZONAS):
                z=ZONAS[int(sel)-1]; zona_estado[z]=dict(SEGURO[z]); control["manual"][z]=None
                print(Fore.GREEN+f"  ✅ {z} reseteada")

        elif op == "5":
            raw=input("  Segundos (1-60): ").strip()
            if raw.isdigit() and 1<=int(raw)<=60:
                control["intervalo"]=int(raw)
                print(Fore.GREEN+f"  Intervalo: {control['intervalo']}s")

        elif op == "6":
            vi=leer_ventilacion(conn)
            for zona in ZONAS:
                vals,factor=simular_ciclo(zona,vi)
                est=estado_gas(vals)
                if insertar(conn,zona,vals,est):
                    imprimir(zona,vals,est,vi.get(zona,{}),factor)
                    alerta(conn,zona,vals,est)
            print(Fore.GREEN+"  ✅ Lecturas insertadas")

        elif op == "7":
            vi=leer_ventilacion(conn)
            print(f"\n  {Fore.CYAN}Ventilación en BD:{Style.RESET_ALL}")
            for zona in ZONAS:
                info=vi.get(zona,{"estado":"—","velocidad":0,"modo":"—"})
                ev=info["estado"]
                sc=Fore.GREEN if ev=="on" else Fore.BLUE if ev=="auto" else Fore.RED
                gv=zona_estado[zona]; ge=estado_gas(gv); gc=COLOR.get(ge,Fore.WHITE)
                print(f"  {SIM.get(ev,'?')} {zona:<22} "
                      f"Vent:{sc}{ev.upper():<5}{Style.RESET_ALL} "
                      f"Vel:{info['velocidad']:>3}%  "
                      f"Gas:{gc}{ge.upper()}{Style.RESET_ALL}  "
                      f"CO:{gv['co']:>6.1f}  O₂:{gv['o2']:>5.2f}")
            input(f"\n  {Fore.WHITE}Enter...{Style.RESET_ALL}")

        elif op == "0":
            control["corriendo"]=False
            print(Fore.CYAN+"\n  👋 Cerrando...\n")
            break

# ─────────────────────────────────────────────
if __name__ == "__main__":
    print(Fore.CYAN+"""
  ╔══════════════════════════════════════════╗
  ║   MINER CLC — Emulador v4.0              ║
  ╚══════════════════════════════════════════╝
""")
    c = conectar()
    if c:
        menu(c)
        c.close()
    else:
        print(Fore.RED+"  ❌ Verifica PostgreSQL y DB_CONFIG")
