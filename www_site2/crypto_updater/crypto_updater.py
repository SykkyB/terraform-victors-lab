#!/usr/bin/env python3

import time
from datetime import datetime
import psycopg2
import requests
import os

# PostgreSQL credentials from environment
DB_HOST = os.getenv("DB_HOST")
DB_PORT = int(os.getenv("DB_PORT", 5432))
DB_NAME = os.getenv("DB_NAME")
DB_USER = os.getenv("DB_USER")
DB_PASS = os.getenv("DB_PASS")

# CoinGecko API URLs
COINGECKO_API = {
    "BTC": "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd",
    "ETH": "https://api.coingecko.com/api/v3/simple/price?ids=ethereum&vs_currencies=usd",
    "SOL": "https://api.coingecko.com/api/v3/simple/price?ids=solana&vs_currencies=usd"
}

def get_price(symbol):
    try:
        response = requests.get(COINGECKO_API[symbol], timeout=5)
        response.raise_for_status()
        data = response.json()
        # Map symbol to CoinGecko ID
        if symbol == "BTC":
            return float(data['bitcoin']['usd'])
        elif symbol == "ETH":
            return float(data['ethereum']['usd'])
        elif symbol == "SOL":
            return float(data['solana']['usd'])
    except Exception as e:
        print(f"[{datetime.utcnow()}] Error fetching {symbol} price: {e}")
        return None

def insert_into_db(btc, eth, sol):
    try:
        conn = psycopg2.connect(
            host=DB_HOST, port=DB_PORT, dbname=DB_NAME, user=DB_USER, password=DB_PASS
        )
        cur = conn.cursor()
        now = datetime.utcnow()
        cur.execute("""
            INSERT INTO crypto_rates (rate_date, rate_time, btc_usd, eth_usd, sol_usd)
            VALUES (%s, %s, %s, %s, %s)
        """, (now.date(), now.time(), btc, eth, sol))
        conn.commit()
        cur.close()
        conn.close()
        print(f"[{now}] Inserted BTC={btc}, ETH={eth}, SOL={sol}")
    except Exception as e:
        print(f"[{datetime.utcnow()}] Error inserting into DB: {e}")

def main():
    while True:
        btc = get_price("BTC")
        eth = get_price("ETH")
        sol = get_price("SOL")

        if btc is not None and eth is not None and sol is not None:
            insert_into_db(btc, eth, sol)
        else:
            print(f"[{datetime.utcnow()}] Skipping DB insert due to missing data.")

        time.sleep(600)  # 10 min interval

if __name__ == "__main__":
    main()
