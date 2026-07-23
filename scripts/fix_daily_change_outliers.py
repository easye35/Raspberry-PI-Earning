#!/usr/bin/env python3
"""
One-off cleanup for the manual-balance save race bug.

Before the fix, saving Repocket + TrafficMonetizer at the same time could
race and briefly zero one of them out, which got written into the earnings
history as a row with a huge negative daily_change. That single row then
drags the 30-day average / projection negative until it ages out.

This script lists your recent rows so you can spot the outlier(s), then lets
you null out a row's daily_change (it stops counting toward the rolling
average, but the row and your totals stay in the history).

Usage:
    python3 fix_daily_change_outliers.py                # list recent rows
    python3 fix_daily_change_outliers.py --null-id 42    # null out row 42
    python3 fix_daily_change_outliers.py --auto          # null obvious outliers automatically

Run this on the Pi against the real DB, e.g.:
    docker compose exec earnings python3 /workdir/scripts/fix_daily_change_outliers.py
or, if running directly on the host with the venv active:
    EARNINGS_DB_PATH=./data/earnings.db python3 scripts/fix_daily_change_outliers.py
"""
import argparse
import os
import sqlite3
import statistics

DB_PATH = os.getenv("EARNINGS_DB_PATH", "/data/earnings.db")


def get_connection():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def list_recent(limit=30):
    conn = get_connection()
    cur = conn.cursor()
    cur.execute(
        "SELECT id, timestamp, total, daily_change, daily_average_30_day, projected_30_day "
        "FROM earnings ORDER BY id DESC LIMIT ?",
        (limit,),
    )
    rows = cur.fetchall()
    conn.close()
    return rows


def find_outliers(rows, z_threshold=2.5):
    changes = [r["daily_change"] for r in rows if r["daily_change"] is not None]
    if len(changes) < 3:
        return []

    median = statistics.median(changes)
    mad = statistics.median([abs(change - median) for change in changes]) or 1.0
    if mad <= 0:
        return []

    outliers = []
    for r in rows:
        dc = r["daily_change"]
        if dc is None:
            continue
        robust_z = abs((dc - median) / mad)
        if robust_z >= z_threshold:
            outliers.append(r["id"])
    return outliers


def null_daily_change(row_id):
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("UPDATE earnings SET daily_change = NULL WHERE id = ?", (row_id,))
    conn.commit()
    conn.close()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--limit", type=int, default=30, help="How many recent rows to show")
    parser.add_argument("--null-id", type=int, help="Null out daily_change for this row id")
    parser.add_argument("--auto", action="store_true", help="Auto-null statistical outliers")
    args = parser.parse_args()

    rows = list_recent(args.limit)

    if args.null_id is not None:
        null_daily_change(args.null_id)
        print(f"Nulled daily_change for row {args.null_id}.")
        print("Note: daily_average_30_day / projected_30_day on the LATEST row won't "
              "recompute until the next earnings update. Trigger one by saving any "
              "manual balance, or wait for the scheduled 16:00 update.")
        return

    if args.auto:
        outlier_ids = find_outliers(rows)
        if not outlier_ids:
            print("No obvious outliers found in the last", args.limit, "rows.")
            return
        for row_id in outlier_ids:
            null_daily_change(row_id)
        print(f"Nulled daily_change for rows: {outlier_ids}")
        print("Note: trigger a fresh earnings update (save any manual balance) to "
              "recompute daily_average_30_day / projected_30_day.")
        return

    print(f"{'id':>4}  {'timestamp':<26}  {'total':>8}  {'daily_change':>13}  {'avg30':>8}  {'proj30':>8}")
    for r in rows:
        dc = r["daily_change"]
        flag = "  <-- suspicious" if dc is not None and abs(dc) > 2 else ""
        print(
            f"{r['id']:>4}  {r['timestamp']:<26}  {r['total']:>8.2f}  "
            f"{'' if dc is None else round(dc, 2):>13}  "
            f"{'' if r['daily_average_30_day'] is None else round(r['daily_average_30_day'], 2):>8}  "
            f"{'' if r['projected_30_day'] is None else round(r['projected_30_day'], 2):>8}{flag}"
        )
    print("\nRe-run with --null-id <id> to clear a specific outlier, or --auto to clear statistical outliers.")


if __name__ == "__main__":
    main()
