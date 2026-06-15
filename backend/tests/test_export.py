"""Tests for GET /api/v1/export"""

import io
import uuid

import pandas as pd
import pytest
from httpx import AsyncClient

from tests.conftest import create_session_payload


@pytest.mark.asyncio
async def test_export_csv_row_count(async_client: AsyncClient) -> None:
    """
    Create a session with 2 exercises x 3 sets each = 6 rows.
    The exported CSV should have exactly 6 data rows (plus 1 header).
    """
    device_uuid = str(uuid.uuid4())

    exercises = [
        {
            "name": "Bench Press",
            "equipment": "barbell",
            "muscle_group": "chest",
            "exercise_order": 0,
            "sets": [
                {"set_number": 1, "reps": 10, "weight": 135.0, "weight_unit": "lbs"},
                {"set_number": 2, "reps": 8, "weight": 145.0, "weight_unit": "lbs"},
                {"set_number": 3, "reps": 6, "weight": 155.0, "weight_unit": "lbs"},
            ],
        },
        {
            "name": "Overhead Press",
            "equipment": "barbell",
            "muscle_group": "shoulders",
            "exercise_order": 1,
            "sets": [
                {"set_number": 1, "reps": 10, "weight": 85.0, "weight_unit": "lbs"},
                {"set_number": 2, "reps": 8, "weight": 95.0, "weight_unit": "lbs"},
                {"set_number": 3, "reps": 6, "weight": 100.0, "weight_unit": "lbs"},
            ],
        },
    ]

    payload = await create_session_payload(
        device_uuid, workout_date="2026-06-15", workout_type="Push", exercises=exercises
    )
    create_resp = await async_client.post("/api/v1/sessions", json=payload)
    assert create_resp.status_code == 201, create_resp.text

    export_resp = await async_client.get(
        "/api/v1/export", params={"device_uuid": device_uuid, "format": "csv"}
    )
    assert export_resp.status_code == 200, export_resp.text
    assert "text/csv" in export_resp.headers["content-type"]
    assert "attachment" in export_resp.headers["content-disposition"]

    # Parse CSV and count rows
    df = pd.read_csv(io.BytesIO(export_resp.content))
    assert len(df) == 6, f"Expected 6 rows, got {len(df)}"

    # Verify expected columns
    expected_cols = {
        "date", "workout_type", "exercise_name", "equipment", "muscle_group",
        "set_number", "reps", "weight", "weight_unit", "duration_seconds", "body_weight_lbs",
    }
    assert expected_cols.issubset(set(df.columns))


@pytest.mark.asyncio
async def test_export_xlsx(async_client: AsyncClient) -> None:
    """Export as XLSX returns correct content-type and parseable data."""
    device_uuid = str(uuid.uuid4())

    exercises = [
        {
            "name": "Squat",
            "equipment": "barbell",
            "muscle_group": "quads",
            "exercise_order": 0,
            "sets": [
                {"set_number": 1, "reps": 5, "weight": 225.0, "weight_unit": "lbs"},
                {"set_number": 2, "reps": 5, "weight": 225.0, "weight_unit": "lbs"},
            ],
        }
    ]
    payload = await create_session_payload(
        device_uuid, workout_date="2026-06-15", workout_type="Legs", exercises=exercises
    )
    create_resp = await async_client.post("/api/v1/sessions", json=payload)
    assert create_resp.status_code == 201

    export_resp = await async_client.get(
        "/api/v1/export", params={"device_uuid": device_uuid, "format": "xlsx"}
    )
    assert export_resp.status_code == 200
    assert (
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        in export_resp.headers["content-type"]
    )

    df = pd.read_excel(io.BytesIO(export_resp.content), sheet_name="Workouts")
    assert len(df) == 2


@pytest.mark.asyncio
async def test_export_empty_returns_header_only(async_client: AsyncClient) -> None:
    """Export with no sessions returns a CSV with headers only (0 data rows)."""
    device_uuid = str(uuid.uuid4())

    export_resp = await async_client.get(
        "/api/v1/export", params={"device_uuid": device_uuid, "format": "csv"}
    )
    assert export_resp.status_code == 200
    df = pd.read_csv(io.BytesIO(export_resp.content))
    assert len(df) == 0


@pytest.mark.asyncio
async def test_export_invalid_format(async_client: AsyncClient) -> None:
    """Export with an unsupported format returns 422."""
    device_uuid = str(uuid.uuid4())

    export_resp = await async_client.get(
        "/api/v1/export", params={"device_uuid": device_uuid, "format": "pdf"}
    )
    assert export_resp.status_code == 422
