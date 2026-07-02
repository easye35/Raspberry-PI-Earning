import os
import smtplib
from email.message import EmailMessage
import json


def _get_smtp_config():
    return {
        "host": os.getenv("SMTP_HOST"),
        "port": int(os.getenv("SMTP_PORT", "587")),
        "user": os.getenv("SMTP_USER"),
        "password": os.getenv("SMTP_PASS"),
        "use_tls": os.getenv("SMTP_TLS", "true").lower() in ("1", "true", "yes"),
    }


def send_snapshot_email(snapshot: dict, to_addr: str = None):
    """Send a simple daily snapshot email. Returns True on success."""
    if to_addr is None:
        to_addr = os.getenv("NOTIFY_TO")
    if not to_addr:
        return False

    cfg = _get_smtp_config()
    if not cfg["host"]:
        return False

    msg = EmailMessage()
    subj = f"EarnBox daily snapshot: {snapshot.get('timestamp') or 'no-timestamp'}"
    msg["Subject"] = subj
    msg["From"] = cfg.get("user") or f"earnbox@{os.uname().nodename}"
    msg["To"] = to_addr

    body = [
        f"Timestamp: {snapshot.get('timestamp')}",
        f"Honeygain: {snapshot.get('honeygain')}",
        f"Pawns: {snapshot.get('pawns')}",
        f"Total: {snapshot.get('total')}",
        f"Daily change: {snapshot.get('daily_change')}",
        f"Projected (30d): {snapshot.get('projected_30_day')}",
        "\nFull JSON attached."
    ]

    msg.set_content("\n".join(body))

    # Attach pretty JSON
    msg.add_attachment(json.dumps(snapshot, indent=2), filename="snapshot.json", subtype="json")

    try:
        if cfg["use_tls"]:
            server = smtplib.SMTP(cfg["host"], cfg["port"], timeout=10)
            server.starttls()
        else:
            server = smtplib.SMTP(cfg["host"], cfg["port"], timeout=10)

        if cfg.get("user") and cfg.get("password"):
            server.login(cfg["user"], cfg["password"])

        server.send_message(msg)
        server.quit()
        return True
    except Exception:
        return False
