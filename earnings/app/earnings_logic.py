import os
import json
import sqlite3
from datetime import datetime, timezone
import subprocess
import re
import shutil
import requests

DB_PATH = os.getenv("EARNINGS_DB_PATH", "/data/earnings.db")
JSON_PATH = os.getenv("EARNINGS_JSON_PATH", "/data/latest_earnings.json")
EARNAPP_COMMAND = os.getenv("EARNAPP_COMMAND", "earnapp")
EARNAPP_STATUS_PATH = os.getenv("EARNAPP_STATUS_PATH")


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
            traffmonetizer REAL NOT NULL DEFAULT 0.0,
            earnapp REAL NOT NULL DEFAULT 0.0,
            total REAL NOT NULL DEFAULT 0.0,
            daily_change REAL,
            projected_30_day REAL
        )
        """
    )

    existing_columns = [row[1] for row in cur.execute("PRAGMA table_info(earnings)").fetchall()]
    for column, default in [
        ("traffmonetizer", 0.0),
        ("earnapp", 0.0),
        ("total", 0.0)
    ]:
        if column not in existing_columns:
            cur.execute(
                f"ALTER TABLE earnings ADD COLUMN {column} REAL NOT NULL DEFAULT {default}"
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
# RATE LIMIT: Prevent refresh more than once every 120 seconds
# ---------------------------------------------------------
LAST_REFRESH = 0
MIN_REFRESH_INTERVAL = 120  # seconds

# ---------------------------------------------------------
# Helper utilities
# ---------------------------------------------------------

def _get_container_logs(container_name, tail=500):
    try:
        client = docker.from_env()
        container = client.containers.get(container_name)
        return container.logs(tail=tail).decode("utf-8", errors="ignore")
    except Exception as e:
        print(f"DEBUG: Failed to read logs for {container_name}: {e}", flush=True)
        return ""


def get_traffmonetizer_balance():
    """Attempts to extract a TraffMonetizer balance estimate from container logs."""
    logs = _get_container_logs("traffmonetizer", tail=1200)
    if not logs:
        print("DEBUG: TraffMonetizer logs empty or container unavailable", flush=True)
        return 0.0

    # Common TraffMonetizer log patterns
    patterns = [
        r"(?:balance|earned|total|payout|income|wallet)\s*[:=]?\s*([0-9]+(?:,[0-9]{3})*(?:\.[0-9]+)?)",
        r"[\"'](?:balance|earned|total|payout|income|wallet)[\"']\s*[:=]\s*([0-9]+(?:,[0-9]{3})*(?:\.[0-9]+)?)",
        r"([0-9]+(?:,[0-9]{3})*(?:\.[0-9]+)?)\s*(?:USD|usd|\$)"
    ]

    for line in reversed(logs.splitlines()):
        for pattern in patterns:
            match = re.search(pattern, line, re.IGNORECASE)
            if match:
                raw_value = match.group(1).replace(",", "")
                try:
                    value = float(raw_value)
                    print(f"DEBUG: TraffMonetizer parsed value {value} from line: {line}", flush=True)
                    return value
                except ValueError:
                    continue

    # Fallback: numeric values on lines that likely mention earnings
    for line in reversed(logs.splitlines()):
        if re.search(r"balance|earned|total|payout|income|usd|\$", line, re.IGNORECASE):
            numbers = re.findall(r"([0-9]+(?:,[0-9]{3})*(?:\.[0-9]+)?)", line)
            if numbers:
                raw_value = numbers[-1].replace(",", "")
                try:
                    value = float(raw_value)
                    print(f"DEBUG: TraffMonetizer fallback parsed value {value} from line: {line}", flush=True)
                    return value
                except ValueError:
                    continue

    # General fallback: last numeric token in all logs
    matches = re.findall(r"([0-9]+(?:,[0-9]{3})*(?:\.[0-9]+)?)", logs)
    if matches:
        raw_value = matches[-1].replace(",", "")
        try:
            value = float(raw_value)
            print(f"DEBUG: TraffMonetizer final fallback parsed value {value}", flush=True)
            return value
        except ValueError:
            pass

    sample_lines = "\n".join(logs.splitlines()[-10:])
    print("DEBUG: TraffMonetizer pattern not found in logs. Last log lines:\n" + sample_lines, flush=True)
    return 0.0


def get_earnapp_balance():
    """Attempts to read native EarnApp balance from a local earnapp CLI or status output."""
    output = ""

    if EARNAPP_STATUS_PATH and os.path.isfile(EARNAPP_STATUS_PATH):
        try:
            with open(EARNAPP_STATUS_PATH, "r", encoding="utf-8") as f:
                output = f.read()
        except Exception as e:
            print("DEBUG: Failed to read EarnApp status file:", e, flush=True)

    if not output and os.path.isdir("/etc/earnapp"):
        try:
            for filename in os.listdir("/etc/earnapp"):
                candidate = os.path.join("/etc/earnapp", filename)
                if os.path.isfile(candidate) and os.path.getsize(candidate) < 100000:
                    with open(candidate, "r", encoding="utf-8", errors="ignore") as f:
                        text = f.read()
                    if re.search(r"balance|wallet|earned|earnings", text, re.IGNORECASE):
                        output = text
                        print(f"DEBUG: EarnApp read status file {candidate}", flush=True)
                        break
        except Exception as e:
            print("DEBUG: EarnApp status directory scan failed:", e, flush=True)

    if not output:
        command = EARNAPP_COMMAND
        if not os.path.isabs(command) or not os.path.exists(command):
            lookup = shutil.which(command)
            if lookup:
                command = lookup
            elif os.path.exists("/usr/bin/earnapp"):
                command = "/usr/bin/earnapp"
            elif os.path.exists("/usr/local/bin/earnapp"):
                command = "/usr/local/bin/earnapp"

        try:
            proc = subprocess.run(
                [command, "status"],
                capture_output=True,
                text=True,
                timeout=10
            )
            output = (proc.stdout or "") + "\n" + (proc.stderr or "")
        except FileNotFoundError:
            print(f"DEBUG: earnapp command not found at {command}", flush=True)
        except Exception as e:
            print("DEBUG: EarnApp balance fetch error:", e, flush=True)

    if not output:
        print("DEBUG: EarnApp output empty", flush=True)

    for line in output.splitlines():
        if re.search(r"(balance|earned|earnings|total|wallet)", line, re.IGNORECASE):
            match = re.search(r"([0-9]+(?:,[0-9]{3})*(?:\.[0-9]+)?)\s*(?:USD|usd|\$)?", line)
            if match:
                raw_value = match.group(1).replace(",", "")
                try:
                    value = float(raw_value)
                    print(f"DEBUG: EarnApp parsed value {value} from line: {line}", flush=True)
                    return value
                except ValueError:
                    continue

    matches = re.findall(r"([0-9]+(?:,[0-9]{3})*(?:\.[0-9]+)?)\s*(?:USD|usd|\$)", output)
    if matches:
        try:
            raw_value = matches[-1].replace(",", "")
            value = float(raw_value)
            print(f"DEBUG: EarnApp fallback parsed value {value} from output", flush=True)
            return value
        except ValueError:
            pass

    print("DEBUG: EarnApp balance not found in output", flush=True)
    return 0.0

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
    traffmonetizer = float(get_traffmonetizer_balance())
    earnapp = float(get_earnapp_balance())
    total = honeygain + pawns + traffmonetizer + earnapp

    last_row = _get_last_row()
    if last_row is not None:
        if "total" in last_row.keys():
            previous_total = float(last_row["total"])
        else:
            previous_total = (
                float(last_row["honeygain"]) +
                float(last_row["pawns"]) +
                float(last_row.get("traffmonetizer", 0.0)) +
                float(last_row.get("earnapp", 0.0))
            )
        daily_change = total - previous_total
    else:
        daily_change = 0.0

    projected_30_day = daily_change * 30

    conn = _get_connection()
    cur = conn.cursor()

    cur.execute(
        """
        INSERT INTO earnings (
            timestamp,
            honeygain,
            pawns,
            traffmonetizer,
            earnapp,
            total,
            daily_change,
            projected_30_day
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            now,
            honeygain,
            pawns,
            traffmonetizer,
            earnapp,
            total,
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
        "traffmonetizer": traffmonetizer,
        "earnapp": earnapp,
        "total": total,
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
        "traffmonetizer": row["traffmonetizer"],
        "earnapp": row["earnapp"],
        "total": row["total"],
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
                "traffmonetizer": row["traffmonetizer"],
                "earnapp": row["earnapp"],
                "total": row["total"],
                "daily_change": row["daily_change"],
                "projected_30_day": row["projected_30_day"],
            }
        )
    return history
