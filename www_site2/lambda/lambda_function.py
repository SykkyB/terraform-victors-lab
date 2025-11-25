# lambda/lambda_function.py
import os
import psycopg2
import requests
from datetime import datetime

DB_HOST = os.getenv("DB_HOST")
DB_PORT = int(os.getenv("DB_PORT", "5432"))
DB_NAME = os.getenv("DB_NAME")
DB_USER = os.getenv("DB_USER")
DB_PASS = os.getenv("DB_PASS")

COINGECKO_URLS = {
    "BTC": "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd",
    "ETH": "https://api.coingecko.com/api/v3/simple/price?ids=ethereum&vs_currencies=usd",
    "SOL": "https://api.coingecko.com/api/v3/simple/price?ids=solana&vs_currencies=usd",
}

def get_price(symbol):
    try:
        r = requests.get(COINGECKO_URLS[symbol], timeout=10)
        r.raise_for_status()
        j = r.json()
        if symbol == "BTC":
            return float(j["bitcoin"]["usd"])
        if symbol == "ETH":
            return float(j["ethereum"]["usd"])
        if symbol == "SOL":
            return float(j["solana"]["usd"])
    except Exception as e:
        print(f"[{datetime.utcnow()}] Error fetching {symbol}: {e}")
        raise

def write_to_db(btc, eth, sol):
    conn = None
    try:
        conn = psycopg2.connect(
            host=DB_HOST, port=DB_PORT, dbname=DB_NAME, user=DB_USER, password=DB_PASS, connect_timeout=10
        )
        cur = conn.cursor()
        now = datetime.utcnow()
        cur.execute("""
            INSERT INTO crypto_rates (rate_date, rate_time, btc_usd, eth_usd, sol_usd)
            VALUES (%s, %s, %s, %s, %s)
        """, (now.date(), now.time().replace(microsecond=0), btc, eth, sol))
        conn.commit()
        cur.close()
        print(f"[{datetime.utcnow()}] Inserted BTC={btc}, ETH={eth}, SOL={sol}")
    except Exception as e:
        print(f"[{datetime.utcnow()}] DB insert error: {e}")
        raise
    finally:
        if conn:
            conn.close()

def lambda_handler(event, context):
    btc = get_price("BTC")
    eth = get_price("ETH")
    sol = get_price("SOL")
    write_to_db(btc, eth, sol)
    return {"status": "ok", "btc": btc, "eth": eth, "sol": sol}
