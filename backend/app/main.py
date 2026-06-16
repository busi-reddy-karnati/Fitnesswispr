from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.routers import (
    parse, sessions, calendar, export, devices, assistant, imports, auth,
    profiles, health,
)

app = FastAPI(
    title="Fitnesswispr API",
    version="1.0.0",
    description="Backend API for the Fitnesswispr workout tracking app",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(parse.router, prefix="/api/v1")
app.include_router(sessions.router, prefix="/api/v1")
app.include_router(calendar.router, prefix="/api/v1")
app.include_router(export.router, prefix="/api/v1")
app.include_router(devices.router, prefix="/api/v1")
app.include_router(assistant.router, prefix="/api/v1")
app.include_router(imports.router, prefix="/api/v1")
app.include_router(auth.router, prefix="/api/v1")
app.include_router(profiles.router, prefix="/api/v1")
app.include_router(health.router, prefix="/api/v1")


@app.get("/api/v1/health")
async def health_check() -> dict:
    return {"status": "ok"}
