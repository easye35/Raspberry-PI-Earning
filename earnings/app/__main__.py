import psutil
from flask import Flask, jsonify, request
from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.cron import CronTrigger
from datetime import datetime
import pytz
from flask_cors import CORS
from . import earnings_logic as logic


def create_app():
    app = Flask(__name__)
    CORS(app)

    # Ensure DB exists
    logic.init_db()

    # ---------------------------------------------------------
    # SYSTEM METRICS
    # ---------------------------------------------------------
    @app.get("/api/system")
    def system_info():
        cpu = psutil.cpu_percent(interval=0.5)
        ram = psutil.virtual_memory().percent
        disk = psutil.disk_usage("/").percent

        # Read Raspberry Pi CPU temperature
        try:
            with open("/sys/class/thermal/thermal_zone0/temp", "r") as f:
                temp_raw = f.read().strip()
                temp = float(temp_raw) / 1000.0
        except:
            temp = None

        return jsonify({
            "ok": True,
            "cpu": cpu,
            "ram": ram,
            "disk": disk,
            "network": {"rx": 0, "tx": 0},
            "temp": temp,
            "uptime": 0
        })

    # ---------------------------------------------------------
    # SERVICES (frontend expects resetService)
    # ---------------------------------------------------------
    @app.get("/api/services")
    def get_services():
        return jsonify({
            "resetService": "OK"
        })

    # ---------------------------------------------------------
    # CONTAINERS (frontend expects an ARRAY)
    # ---------------------------------------------------------
    @app.get("/api/containers")
    def get_containers():
        return jsonify([])

    # ---------------------------------------------------------
    # 7-DAY PROJECTION
    # ---------------------------------------------------------
    @app.get("/api/projection/7day")
    def projection_7day():
        history = logic.get_history(limit=7)
        total = sum((item.get("daily_change") or 0) for item in history)
        avg = total / 7 if history else 0

        return jsonify({
            "projection": round(avg * 30, 2)
        })

    # ---------------------------------------------------------
    # EARNINGS ROUTES
    # ---------------------------------------------------------
    @app.get("/earnings")
    def get_earnings():
        snapshot = logic.get_latest_snapshot()
        return jsonify(snapshot)

    @app.get("/earnings/history")
    def get_earnings_history():
        try:
            limit = int(request.args.get("limit", "30"))
        except ValueError:
            limit = 30

        history = logic.get_history(limit=limit)
        return jsonify({
            "count": len(history),
            "items": history
        })

    @app.post("/earnings/run-now")
    def run_now():
        return jsonify({
            "error": "Run-now is disabled. Earnings are served from stored database snapshots."
        }), 404

    return app


def _start_scheduler(app):
    scheduler = BackgroundScheduler(timezone=pytz.timezone("America/Edmonton"))

    def job_wrapper():
        with app.app_context():
            app.logger.info("Running scheduled earnings update at %s", datetime.now())
            try:
                logic.update_earnings()
            except Exception:
                app.logger.exception("Scheduled earnings update failed")

    trigger = CronTrigger(hour=16, minute=0)
    scheduler.add_job(job_wrapper, trigger,
                      id="daily_earnings_update",
                      replace_existing=True)

    scheduler.start()
    app.logger.info("Scheduler started: daily at 16:00 America/Edmonton")


app = create_app()
_start_scheduler(app)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
