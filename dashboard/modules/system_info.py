import psutil
import subprocess
import time
import os

def get_uptime():
    return int(time.time() - psutil.boot_time())

def get_cpu():
    return psutil.cpu_percent(interval=0.5)

def get_memory():
    mem = psutil.virtual_memory()
    return mem.percent

def get_disk():
    disk = psutil.disk_usage("/")
    return disk.percent

def get_temp():
    try:
        out = subprocess.check_output(["vcgencmd", "measure_temp"], text=True)
        return float(out.replace("temp=", "").replace("'C", ""))
    except:
        return None
