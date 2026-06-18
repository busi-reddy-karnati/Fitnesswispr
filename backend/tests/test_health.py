"""Tests for Apple Health day sync/fetch (shared so spotters can see it)."""
import uuid

import pytest
from httpx import AsyncClient


def _workout(date_str: str, category: str = "Strength") -> dict:
    return {
        "workout_date": date_str,
        "category": category,
        "symbol": "dumbbell.fill",
        "duration_minutes": 45,
    }


@pytest.mark.asyncio
async def test_health_check_still_works(async_client: AsyncClient) -> None:
    """The /health Apple-fitness routes must not shadow the health check."""
    resp = await async_client.get("/api/v1/health")
    assert resp.status_code == 200
    assert resp.json() == {"status": "ok"}


@pytest.mark.asyncio
async def test_health_sync_and_fetch(async_client: AsyncClient) -> None:
    device = str(uuid.uuid4())
    body = {
        "device_uuid": device,
        "workouts": [_workout("2026-06-10"), _workout("2026-06-12", "Running")],
    }
    resp = await async_client.post("/api/v1/health/sync", json=body)
    assert resp.status_code == 204, resp.text

    listing = await async_client.get("/api/v1/health/days", params={"device_uuid": device})
    assert listing.status_code == 200
    days = listing.json()
    assert len(days) == 2
    assert {d["workout_date"] for d in days} == {"2026-06-10", "2026-06-12"}


@pytest.mark.asyncio
async def test_health_sync_replaces_previous(async_client: AsyncClient) -> None:
    device = str(uuid.uuid4())
    await async_client.post(
        "/api/v1/health/sync",
        json={"device_uuid": device, "workouts": [_workout("2026-06-10")]},
    )
    # Re-sync with a different set; the old day should be gone.
    await async_client.post(
        "/api/v1/health/sync",
        json={"device_uuid": device, "workouts": [_workout("2026-06-15")]},
    )
    listing = await async_client.get("/api/v1/health/days", params={"device_uuid": device})
    days = listing.json()
    assert len(days) == 1
    assert days[0]["workout_date"] == "2026-06-15"


@pytest.mark.asyncio
async def test_health_fetch_isolated_by_device(async_client: AsyncClient) -> None:
    a, b = str(uuid.uuid4()), str(uuid.uuid4())
    await async_client.post(
        "/api/v1/health/sync",
        json={"device_uuid": a, "workouts": [_workout("2026-06-10")]},
    )
    listing = await async_client.get("/api/v1/health/days", params={"device_uuid": b})
    assert listing.json() == []
