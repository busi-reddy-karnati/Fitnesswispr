"""Tests for payload size limits on write endpoints (DB/memory abuse guards)."""

import pytest
from httpx import AsyncClient

from app.config import settings

DEV = "11111111-1111-1111-1111-111111111111"


def _exercise(n_sets: int = 1) -> dict:
    return {
        "name": "Bench Press",
        "exercise_order": 0,
        "sets": [
            {"set_number": i, "reps": 10, "weight": 135.0, "weight_unit": "lbs"}
            for i in range(n_sets)
        ],
    }


@pytest.mark.asyncio
async def test_too_many_exercises_rejected(async_client: AsyncClient) -> None:
    body = {
        "device_uuid": DEV,
        "workout_date": "2026-06-16",
        "source": "manual",
        "exercises": [_exercise() for _ in range(settings.MAX_EXERCISES_PER_SESSION + 1)],
    }
    r = await async_client.post("/api/v1/sessions", json=body)
    assert r.status_code == 422


@pytest.mark.asyncio
async def test_too_many_sets_rejected(async_client: AsyncClient) -> None:
    body = {
        "device_uuid": DEV,
        "workout_date": "2026-06-16",
        "source": "manual",
        "exercises": [_exercise(n_sets=settings.MAX_SETS_PER_EXERCISE + 1)],
    }
    r = await async_client.post("/api/v1/sessions", json=body)
    assert r.status_code == 422


@pytest.mark.asyncio
async def test_normal_session_still_ok(async_client: AsyncClient) -> None:
    body = {
        "device_uuid": DEV,
        "workout_date": "2026-06-16",
        "source": "manual",
        "exercises": [_exercise(n_sets=3), _exercise(n_sets=3)],
    }
    r = await async_client.post("/api/v1/sessions", json=body)
    assert r.status_code == 201, r.text


@pytest.mark.asyncio
async def test_too_many_commit_items_rejected(async_client: AsyncClient) -> None:
    item = {"device_uuid": DEV, "workout_date": "2026-06-16", "exercises": []}
    body = {"items": [item for _ in range(settings.MAX_COMMIT_ITEMS + 1)]}
    r = await async_client.post("/api/v1/import/commit", json=body)
    assert r.status_code == 422


@pytest.mark.asyncio
async def test_request_body_too_large(async_client: AsyncClient, monkeypatch) -> None:
    monkeypatch.setattr(settings, "MAX_REQUEST_BODY_BYTES", 10)  # tiny cap for the test
    r = await async_client.post(
        "/api/v1/parse",
        json={"transcript": "bench", "device_uuid": DEV, "unit_preference": "lbs", "context": {}},
    )
    assert r.status_code == 413
    assert "too large" in r.json()["detail"].lower()
