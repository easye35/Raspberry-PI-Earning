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

    # ---------- API ROUTES ----------

    @app.get("/earnings")
    def get_earnings():
        """
        Returns the latest earnings snapshot.
        """
        snapshot = logic.get_latest_snapshot()
        if snapshot is None:
            return (
                jsonify(
                    {
                        "message": "No earnings data yet. Wait for the first scheduled run.",
                    }
                ),
                404,
            )
        return jsonify(snapshot)

    @app.get("/earnings/history")
    def get_earnings_history():
        """
        Returns last N entries (default 30).
        """
        try:
            limit = int(request.args.get("limit", "30"))
        except ValueError:
            limit = 30
        history = logic.get_history(limit=limit)
        return jsonify({"count": len(history), "items": history})

    @app.post("/earnings/run-now")
    def run_now():
        """
        Manual trigger for testing from browser or curl.
        """
        snapshot = logic.update_earnings()
        return jsonify(snapshot)

    return app


def _start_scheduler(app):
    """
    Start APScheduler to run update_earnings daily at 16:00 Edmonton time.
    """
    scheduler = BackgroundScheduler(timezone=pytz.timezone("America/Edmonton"))

    def job_wrapper():
        with app.app_context():
            app.logger.info("Running scheduled earnings update at %s", datetime.now())
            logic.update_earnings()

    # Every day at 16:00
    trigger = CronTrigger(hour=16, minute=0)
    scheduler.add_job(job_wrapper, trigger, id="daily_earnings_update", replace_existing=True)
    scheduler.start()
    app.logger.info("Scheduler started: daily at 16:00 America/Edmonton")


app = create_app()
_start_scheduler(app)

if __name__ == "__main__":
    # For local testing; in Docker we still use this.
    app.run(host="0.0.0.0", port=5000)
