from fastapi import APIRouter
from modules import services

router = APIRouter()

@router.get("/services")
def list_all():
    return services.list_services()

@router.post("/services/{name}/restart")
def restart(name: str):
    ok = services.restart_service(name)
    return {"success": ok}
