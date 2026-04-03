from fastapi import FastAPI
from routers import dashboard, system, services, logs

app = FastAPI()

app.include_router(dashboard.router, prefix="/api")
app.include_router(system.router, prefix="/api")
app.include_router(services.router, prefix="/api")
app.include_router(logs.router, prefix="/api")
