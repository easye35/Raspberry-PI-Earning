from fastapi import APIRouter
from modules import system_info

router = APIRouter()

@router.get("/system")
def system():
    return {
        "cpu": system_info.get_cpu(),
        "memory": system_info.get_memory(),
        "disk": system_info.get_disk(),
        "uptime": system_info.get_uptime(),
        "temp": system_info.get_temp(),
    }
