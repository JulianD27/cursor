import psycopg2

try:
    c = psycopg2.connect(host="localhost", port=5432, dbname="miner_clc", user="postgres", password="minercl c123")
    cur = c.cursor()
    
    tables = ['alertas', 'lecturas_gases', 'ventilacion', 'usuarios', 'auditoria_logs', 'respaldos_historial']
    
    for t in tables:
        cur.execute(f"SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='public' AND table_name='{t}'")
        cols = cur.fetchall()
        print(f"Table {t}:")
        if not cols:
            print("  (Table not found or no columns)")
        else:
            for col in cols:
                print(f"  {col[0]} ({col[1]})")
        print("-" * 20)
        
    c.close()
except Exception as e:
    print(f"Database error: {e}")
