import os
import json
import sqlite3
from datetime import datetime, timezone
import subprocess
import re
import requests

DB_PATH = os.getenv("EARNINGS_DB_PATH", "/data/earnings.db")
JSON_PATH = os.getenv("EARNINGS_JSON_PATH", "/data/latest_earnings.json")


# ---------------------------------------------------------
# DATABASE HELPERS
# ---------------------------------------------------------

def _get_connection():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    conn = _get_connection()
    cur = conn.cursor()
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS earnings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT NOT NULL,
            honeygain REAL NOT NULL,
            pawns REAL NOT NULL,
            daily_change REAL,
            projected_30_day REAL
        )
        """
    )
    conn.commit()
    conn.close()


def _get_last_row():
    conn = _get_connection()
    cur = conn.cursor()
    cur.execute("SELECT * FROM earnings ORDER BY id DESC LIMIT 1")
    row = cur.fetchone()
    conn.close()
    return row

# ---------------------------------------------------------
# RATE LIMIT: Prevent refresh more than once every 5 minutes
# ---------------------------------------------------------
LAST_REFRESH = 0
MIN_REFRESH_INTERVAL = 3000  # seconds

# ---------------------------------------------------------
# BALANCE FETCHERS
# ---------------------------------------------------------

import docker

def get_pawns_balance():
    """
    Reads Pawns logs using Docker SDK (works inside containers).
    """

    try:
        client = docker.from_env()
        container = client.containers.get("pawns")
        logs = container.logs(tail=300).decode("utf-8", errors="ignore")
    except Exception as e:
        print("DEBUG: Pawns log read error:", e, flush=True)
        return 0.0

    latest_balance = None

    for line in logs.splitlines():
        if "balance_ready" in line:
            try:
                data = json.loads(line)
                bal_str = data["parameters"]["balance"]  # "0.399 USD"
                match = re.match(r"([0-9.]+)", bal_str)
                if match:
                    latest_balance = float(match.group(1))
            except Exception:
                continue

    return latest_balance if latest_balance is not None else 0.0

def get_honeygain_balance():
    """
    Fetch Honeygain balance using the official API.
    Handles both old and new payout formats.
    """

    email = os.getenv("HONEYGAIN_EMAIL")
    password = os.getenv("HONEYGAIN_PASSWORD")

    if not email or not password:
        print("DEBUG: Missing Honeygain credentials", flush=True)
        return 0.0

    # Step 1: Login
    try:
        login_resp = requests.post(
            "https://dashboard.honeygain.com/api/v1/users/tokens",
            json={"email": email, "password": password},
            timeout=10
        )

        if login_resp.status_code != 200:
            print("DEBUG: Honeygain login failed:", login_resp.text[:200], flush=True)
            return 0.0

        token = login_resp.json().get("data", {}).get("access_token")
        if not token:
            print("DEBUG: Honeygain token missing", flush=True)
            print("DEBUG: Raw login response:", login_resp.text[:300], flush=True)
            return 0.0

    except Exception as e:
        print("DEBUG: Honeygain login exception:", e, flush=True)
        return 0.0

    # Step 2: Fetch balance
    try:
        bal_resp = requests.get(
            "https://dashboard.honeygain.com/api/v1/users/balances",
            headers={"Authorization": f"Bearer {token}"},
            timeout=10
        )

        print("DEBUG: Honeygain RAW BALANCE RESPONSE:", bal_resp.text, flush=True)

        if bal_resp.status_code != 200:
            print("DEBUG: Honeygain balance error:", bal_resp.text[:200], flush=True)
            return 0.0

        raw = bal_resp.json()
        data = raw.get("data", {})

        payout = data.get("payout", {})

        # Your account uses usd_cents
        if isinstance(payout, dict):
            usd_cents = payout.get("usd_cents", 0)
            balance = usd_cents / 100.0
        else:
            balance = float(payout)

        return float(balance)

    except Exception as e:
        print("DEBUG: Honeygain balance exception:", e, flush=True)
        return 0.0


# ---------------------------------------------------------
# CORE LOGIC
# ---------------------------------------------------------

import time

def update_earnings():
    global LAST_REFRESH

    now = time.time()

    # If called too soon → return cached JSON
    if now - LAST_REFRESH < MIN_REFRESH_INTERVAL:
        try:
            with open(JSON_PATH, "r") as f:
                return json.load(f)
        except:
            pass  # If no JSON exists, fall through and fetch fresh

    # Otherwise → fetch fresh
    LAST_REFRESH = now

    """
    Fetches balances, computes daily change + projection,
    stores in SQLite, writes JSON snapshot.
    """

    init_db()
    now = datetime.now(timezone.utc).isoformat()

    honeygain = float(get_honeygain_balance())
    pawns = float(get_pawns_balance())

    today_total = honeygain + pawns

    last_row = _get_last_row()
    if last_row is not None:
        yesterday_total = (
            float(last_row["honeygain"])
            + float(last_row["pawns"])
        )
        daily_change = today_total - yesterday_total
    else:
        daily_change = None

    projected_30_day = daily_change * 30 if daily_change is not None else None

    conn = _get_connection()
    cur = conn.cursor()

    # FIXED: 5 columns → 5 placeholders
    cur.execute(
        """
        INSERT INTO earnings (
            timestamp, honeygain, pawns, daily_change, projected_30_day
        ) VALUES (?, ?, ?, ?, ?)
        """,
        (
            now,
            honeygain,
            pawns,
            daily_change,
            projected_30_day,
        ),
    )

    conn.commit()
    conn.close()

    snapshot = {
        "timestamp": now,
        "honeygain": honeygain,
        "pawns": pawns,
        "daily_change": daily_change,
        "projected_30_day": projected_30_day,
    }

    os.makedirs(os.path.dirname(JSON_PATH), exist_ok=True)
    with open(JSON_PATH, "w", encoding="utf-8") as f:
        json.dump(snapshot, f, indent=2)

    return snapshot


def get_latest_snapshot():
    init_db()
    row = _get_last_row()
    if row is None:
        return None

    return {
        "id": row["id"],
        "timestamp": row["timestamp"],
        "honeygain": row["honeygain"],
        "pawns": row["pawns"],
        "daily_change": row["daily_change"],
        "projected_30_day": row["projected_30_day"],
    }


def get_history(limit: int = 30):
    init_db()
    conn = _get_connection()
    cur = conn.cursor()
    cur.execute(
        "SELECT * FROM earnings ORDER BY id DESC LIMIT ?",
        (limit,),
    )
    rows = cur.fetchall()
    conn.close()

    history = []
    for row in rows:
        history.append(
            {
                "id": row["id"],
                "timestamp": row["timestamp"],
                "honeygain": row["honeygain"],
                "pawns": row["pawns"],
                "daily_change": row["daily_change"],
                "projected_30_day": row["projected_30_day"],
            }
        )
    return history
