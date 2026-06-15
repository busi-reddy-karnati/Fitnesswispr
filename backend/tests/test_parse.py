"""Tests for POST /api/v1/parse"""

import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_parse_returns_correct_shape(async_client: AsyncClient) -> None:
    """Mocked Gemini returns a Push workout; verify shape matches WorkoutSessionSchema."""
    device_uuid = "00000000-0000-0000-0000-000000000001"
    payload = {
        "transcript": "I did 3 sets of bench press at 135 lbs for 10 reps",
        "device_uuid": device_uuid,
        "unit_preference": "lbs",
        "context": {},
    }

    response = await async_client.post("/api/v1/parse", json=payload)
    assert response.status_code == 200, response.text

    data = response.json()
    # session_id must be null (not saved)
    assert data["session_id"] is None
    assert data["workout_type"] == "Push"
    assert isinstance(data["exercises"], list)
    assert len(data["exercises"]) >= 1

    first_exercise = data["exercises"][0]
    assert "name" in first_exercise
    assert isinstance(first_exercise["sets"], list)


@pytest.mark.asyncio
async def test_parse_passes_context_body_weight(async_client: AsyncClient) -> None:
    """Context body_weight_lbs is forwarded to gemini_service."""
    device_uuid = "00000000-0000-0000-0000-000000000001"
    payload = {
        "transcript": "Bench press 3x10 at 185",
        "device_uuid": device_uuid,
        "unit_preference": "lbs",
        "context": {"body_weight_lbs": 185.0},
    }

    response = await async_client.post("/api/v1/parse", json=payload)
    assert response.status_code == 200, response.text
    data = response.json()
    assert data["session_id"] is None


@pytest.mark.asyncio
async def test_parse_returns_422_on_parse_error(
    async_client_parse_error: AsyncClient,
) -> None:
    """When Gemini returns parse_error=true, the endpoint returns HTTP 422."""
    payload = {
        "transcript": "blah blah not a workout",
        "device_uuid": "00000000-0000-0000-0000-000000000001",
        "unit_preference": "lbs",
        "context": {},
    }

    response = await async_client_parse_error.post("/api/v1/parse", json=payload)
    assert response.status_code == 422, response.text
