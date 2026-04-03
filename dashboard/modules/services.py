import subprocess

def list_services():
    try:
        out = subprocess.check_output(
            ["systemctl", "list-units", "--type=service", "--no-pager", "--no-legend"],
            text=True
        )
        services = []
        for line in out.splitlines():
            parts = line.split()
            if len(parts) >= 4:
                services.append({
                    "name": parts[0],
                    "load": parts[1],
                    "active": parts[2],
                    "sub": parts[3]
                })
        return services
    except:
        return []

def restart_service(name):
    try:
        subprocess.check_call(["sudo", "systemctl", "restart", name])
        return True
    except:
        return False
