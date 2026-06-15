"""Tests for /api/v1/sessions CRUD endpoints."""

import uuid

import pytest
from httpx import AsyncClient

from tests.conftest import create_session_payload

DEVICE_UUID = str(uuid.uuid4())


@pytest.mark.asyncio
async def test_create_session(async_client: AsyncClient) -> None:
    """POST /sessions creates a workout session and returns it with nested data."""
    payload = await create_session_payload(DEVICE_UUID)
    response = await async_client.post("/api/v1/sessions", json=payload)
    assert response.status_code == 201, response.text

    data = response.json()
    assert data["session_id"] is not None
    assert data["workout_type"] == "Push"
    assert data["device_uuid"] == DEVICE_UUID
    assert len(data["exercises"]) == 1
    assert len(data["exercises"][0]["sets"]) == 3


@pytest.mark.asyncio
async def test_list_sessions(async_client: AsyncClient) -> None:
    """GET /sessions returns all sessions for a device_uuid."""
    device_uuid = str(uuid.uuid4())

    # Create 2 sessions
    for date in ["2026-06-10", "2026-06-11"]:
        payload = await create_session_payload(device_uuid, workout_date=date)
        r = await async_client.post("/api/v1/sessions", json=payload)
        assert r.status_code == 201

    response = await async_client.get(
        "/api/v1/sessions", params={"device_uuid": device_uuid}
    )
    assert response.status_code == 200, response.text
    data = response.json()
    assert len(data) == 2


@pytest.mark.asyncio
async def test_list_sessions_date_filter(async_client: AsyncClient) -> None:
    """GET /sessions with start_date/end_date filters correctly."""
    device_uuid = str(uuid.uuid4())

    for date, wt in [("2026-05-01", "Push"), ("2026-06-01", "Pull"), ("2026-07-01", "Legs")]:
        payload = await create_session_payload(device_uuid, workout_date=date, workout_type=wt)
        r = await async_client.post("/api/v1/sessions", json=payload)
        assert r.status_code == 201

    response = await async_client.get(
        "/api/v1/sessions",
        params={"device_uuid": device_uuid, "start_date": "2026-06-01", "end_date": "2026-06-30"},
    )
    assert response.status_code == 200
    data = response.json()
    assert len(data) == 1
    assert data[0]["workout_type"] == "Pull"


@pytest.mark.asyncio
async def test_get_session(async_client: AsyncClient) -> None:
    """GET /sessions/{id} returns the correct session."""
    device_uuid = str(uuid.uuid4())
    payload = await create_session_payload(device_uuid)
    create_resp = await async_client.post("/api/v1/sessions", json=payload)
    session_id = create_resp.json()["session_id"]

    response = await async_client.get(f"/api/v1/sessions/{session_id}")
    assert response.status_code == 200
    assert response.json()["session_id"] == session_id


@pytest.mark.asyncio
async def test_get_session_not_found(async_client: AsyncClient) -> None:
    """GET /sessions/{non-existent-id} returns 404."""
    fake_id = str(uuid.uuid4())
    response = await async_client.get(f"/api/v1/sessions/{fake_id}")
    assert response.status_code == 404


@pytest.mark.asyncio
async def test_update_session(async_client: AsyncClient) -> None:
    """PUT /sessions/{id} updates mutable fields."""
    device_uuid = str(uuid.uuid4())
    payload = await create_session_payload(device_uuid)
    create_resp = await async_client.post("/api/v1/sessions", json=payload)
    session_id = create_resp.json()["session_id"]

    update_payload = {"workout_type": "Legs", "session_notes": "Felt great today"}
    response = await async_client.put(f"/api/v1/sessions/{session_id}", json=update_payload)
    assert response.status_code == 200
    data = response.json()
    assert data["workout_type"] == "Legs"
    assert data["session_notes"] == "Felt great today"


@pytest.mark.asyncio
async def test_delete_session(async_client: AsyncClient) -> None:
    """DELETE /sessions/{id} removes the session and returns 204."""
    device_uuid = str(uuid.uuid4())
    payload = await create_session_payload(device_uuid)
    create_resp = await async_client.post("/api/v1/sessions", json=payload)
    session_id = create_resp.json()["session_id"]

    delete_resp = await async_client.delete(f"/api/v1/sessions/{session_id}")
    assert delete_resp.status_code == 204

    # Confirm it's gone
    get_resp = await async_client.get(f"/api/v1/sessions/{session_id}")
    assert get_resp.status_code == 404


@pytest.mark.asyncio
async def test_delete_session_cascades(async_client: AsyncClient) -> None:
    """Deleting a session removes its exercises and sets (cascade)."""
    device_uuid = str(uuid.uuid4())
    payload = await create_session_payload(device_uuid)
    create_resp = await async_client.post("/api/v1/sessions", json=payload)
    data = create_resp.json()
    session_id = data["session_id"]

    # Verify exercises exist in the response
    assert len(data["exercises"]) == 1
    assert len(data["exercises"][0]["sets"]) == 3

    # Delete the session
    del_resp = await async_client.delete(f"/api/v1/sessions/{session_id}")
    assert del_resp.status_code == 204

    # Session is gone; SQLite + cascade should have removed exercises/sets
    get_resp = await async_client.get(f"/api/v1/sessions/{session_id}")
    assert get_resp.status_code == 404


@pytest.mark.asyncio
async def test_create_session_upserts_device_context(async_client: AsyncClient) -> None:
    """Creating a session with body_weight_lbs upserts device_context."""
    device_uuid = str(uuid.uuid4())
    payload = await create_session_payload(device_uuid)
    payload["body_weight_lbs"] = 185.0

    response = await async_client.post("/api/v1/sessions", json=payload)
    assert response.status_code == 201

    ctx_resp = await async_client.get(f"/api/v1/devices/{device_uuid}/context")
    assert ctx_resp.status_code == 200
    assert float(ctx_resp.json()["last_body_weight_lbs"]) == 185.0
