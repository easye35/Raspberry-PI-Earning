from fastapi import APIRouter
import subprocess

router = APIRouter()

@router.get("/logs/{service}")
def logs(service: str):
    try:
        out = subprocess.check_output(
            ["journalctl", "-u", service, "-n", "200", "--no-pager"],
            text=True
        )
        return {"logs": out}
    except:
        return {"logs": "Unable to read logs."}
