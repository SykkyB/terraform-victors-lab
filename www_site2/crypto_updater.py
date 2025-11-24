#!/usr/bin/env python3

import time
from datetime import datetime
import psycopg2
import requests

# PostgreSQL credentials
import os

DB_HOST = os.getenv("DB_HOST")
DB_PORT = int(os.getenv("DB_PORT", 5432))
DB_NAME = os.getenv("DB_NAME")
DB_USER = os.getenv("DB_USER")
DB_PASS = os.getenv("DB_PASS")


# Binance API URLs for latest price
BINANCE_API = {
    "BTC": "https://api.binance.com/api/v3/ticker/price?symbol=BTCUSDT",
    "ETH": "https://api.binance.com/api/v3/ticker/price?symbol=ETHUSDT",
    "SOL": "https://api.binance.com/api/v3/ticker/price?symbol=SOLUSDT"
}

def get_price(symbol):
    try:
        response = requests.get(BINANCE_API[symbol], timeout=5)
        response.raise_for_status()
        data = response.json()
        return float(data['price'])
    except Exception as e:
        print(f"Error fetching {symbol} price: {e}")
        return None

def insert_into_db(btc, eth, sol):
    try:
        conn = psycopg2.connect(
            host=DB_HOST,
            port=DB_PORT,
            dbname=DB_NAME,
            user=DB_USER,
            password=DB_PASS
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
        print(f"Inserted BTC={btc}, ETH={eth}, SOL={sol} at {now}")
    except Exception as e:
        print(f"Error inserting into DB: {e}")

def main():
    while True:
        btc = get_price("BTC")
        eth = get_price("ETH")
        sol = get_price("SOL")

        if btc and eth and sol:
            insert_into_db(btc, eth, sol)

        time.sleep(600)  # Wait 10 minutes

if __name__ == "__main__":
    main()
