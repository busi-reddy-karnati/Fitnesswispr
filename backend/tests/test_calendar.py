"""Tests for GET /api/v1/calendar"""

import uuid

import pytest
from httpx import AsyncClient

from tests.conftest import create_session_payload


@pytest.mark.asyncio
async def test_calendar_returns_correct_dates(async_client: AsyncClient) -> None:
    """Create 3 sessions on different dates; calendar returns correct entries."""
    device_uuid = str(uuid.uuid4())

    sessions_data = [
        ("2026-06-01", "Push"),
        ("2026-06-10", "Pull"),
        ("2026-06-20", "Legs"),
    ]

    for date, workout_type in sessions_data:
        payload = await create_session_payload(
            device_uuid, workout_date=date, workout_type=workout_type
        )
        r = await async_client.post("/api/v1/sessions", json=payload)
        assert r.status_code == 201, r.text

    response = await async_client.get(
        "/api/v1/calendar",
        params={"device_uuid": device_uuid, "year": 2026, "month": 6},
    )
    assert response.status_code == 200, response.text

    data = response.json()
    assert "dates" in data
    dates_list = data["dates"]
    assert len(dates_list) == 3

    # Verify each date and workout_type match what we created
    date_map = {entry["date"]: entry["workout_type"] for entry in dates_list}
    assert date_map["2026-06-01"] == "Push"
    assert date_map["2026-06-10"] == "Pull"
    assert date_map["2026-06-20"] == "Legs"


@pytest.mark.asyncio
async def test_calendar_filters_by_month(async_client: AsyncClient) -> None:
    """Sessions from other months are not returned."""
    device_uuid = str(uuid.uuid4())

    # Create sessions in June and July
    for date, wt in [("2026-06-15", "Push"), ("2026-07-01", "Pull")]:
        payload = await create_session_payload(device_uuid, workout_date=date, workout_type=wt)
        r = await async_client.post("/api/v1/sessions", json=payload)
        assert r.status_code == 201

    response = await async_client.get(
        "/api/v1/calendar",
        params={"device_uuid": device_uuid, "year": 2026, "month": 6},
    )
    assert response.status_code == 200
    dates_list = response.json()["dates"]
    assert len(dates_list) == 1
    assert dates_list[0]["date"] == "2026-06-15"
    assert dates_list[0]["workout_type"] == "Push"


@pytest.mark.asyncio
async def test_calendar_empty_month(async_client: AsyncClient) -> None:
    """A month with no workouts returns an empty dates list."""
    device_uuid = str(uuid.uuid4())

    response = await async_client.get(
        "/api/v1/calendar",
        params={"device_uuid": device_uuid, "year": 2025, "month": 1},
    )
    assert response.status_code == 200
    assert response.json() == {"dates": []}


@pytest.mark.asyncio
async def test_calendar_isolates_by_device(async_client: AsyncClient) -> None:
    """Sessions from a different device are not returned."""
    device1 = str(uuid.uuid4())
    device2 = str(uuid.uuid4())

    payload = await create_session_payload(device1, workout_date="2026-06-05", workout_type="Push")
    r = await async_client.post("/api/v1/sessions", json=payload)
    assert r.status_code == 201

    response = await async_client.get(
        "/api/v1/calendar",
        params={"device_uuid": device2, "year": 2026, "month": 6},
    )
    assert response.status_code == 200
    assert response.json()["dates"] == []
