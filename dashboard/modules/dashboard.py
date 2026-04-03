from fastapi import APIRouter
from modules import docker_stats, system_info, earnings

router = APIRouter()

@router.get("/dashboard")
def dashboard():
    return {
        "system": {
            "cpu": system_info.get_cpu(),
            "memory": system_info.get_memory(),
            "disk": system_info.get_disk(),
            "uptime": system_info.get_uptime(),
            "temp": system_info.get_temp(),
        },
        "containers": docker_stats.get_container_stats(),
        "earnings": earnings.get_earnings()
    }
