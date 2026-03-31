from flask import Flask, jsonify
from flask_cors import CORS
import docker
import psutil
import subprocess
import time
import os

app = Flask(__name__)
CORS(app)
client = docker.from_env()

def get_container_status():
    containers = {}
    for c in client.containers.list(all=True):
        containers[c.name] = c.status
    return containers

def get_health_status():
    health = {}
    for c in client.containers.list(all=True):
        try:
            state = c.attrs["State"]
            if "Health" in state:
                health[c.name] = state["Health"]["Status"]
            else:
                health[c.name] = "unknown"
        except:
            health[c.name] = "unknown"
    return health

def get_system_stats():
    # CPU load averages
    load1, load5, load15 = os.getloadavg()
    cpu_load = f"{load1:.2f}, {load5:.2f}, {load15:.2f}"

    # RAM
    mem = psutil.virtual_memory()
    ram = f"{mem.used / (1024*1024):.1f}M/{mem.total / (1024*1024*1024):.1f}G"

    # Disk
    disk = psutil.disk_usage("/")
    disk_used = f"{disk.percent}%"

    # Temperature (Pi-specific)
    try:
        temp = subprocess.check_output(["vcgencmd", "measure_temp"]).decode()
        temp = temp.replace("temp=", "").strip()
    except:
        temp = "N/A"

    # Uptime
    try:
        uptime_seconds = time.time() - psutil.boot_time()
        uptime = f"{uptime_seconds:.0f}s"
    except:
        uptime = "N/A"

    return {
        "cpu_load": cpu_load,
        "ram": ram,
        "disk": disk_used,
        "temp": temp,
        "uptime": uptime
    }

@app.route("/")
def diagnostics():
    try:
        data = {
            "docker_running": "yes",
            "containers": get_container_status(),
            "healthchecks": get_health_status(),
            "system": get_system_stats()
        }
        return jsonify(data)
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=7000)
