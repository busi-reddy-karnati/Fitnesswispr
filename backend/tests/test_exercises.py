"""Tests for bulk exercise rename/merge and name canonicalization."""
import uuid

import pytest

from app.services import exercise_name
from tests.conftest import create_session_payload


def _ex(name: str) -> list:
    return [
        {
            "name": name,
            "equipment": None,
            "muscle_group": "back",
            "exercise_order": 0,
            "sets": [
                {"set_number": 1, "reps": 10, "weight": 100.0, "weight_unit": "lbs"},
            ],
        }
    ]


# ---------------------------------------------------------------------------
# Canonicalization
# ---------------------------------------------------------------------------
def test_canonical_merges_plural():
    assert exercise_name.same_exercise("Lat Pulldown", "Lat Pulldowns")
    assert exercise_name.same_exercise("Leg Extension", "Leg Extensions")


def test_canonical_keeps_press():
    # "press" must not be singularized to "pres".
    assert exercise_name.canonical_key("Bench Press") == "bench press"
    assert exercise_name.same_exercise("Bench Presses", "Bench Press")


def test_canonical_synonyms():
    assert exercise_name.same_exercise("Overhead Press", "Shoulder Press")
    assert exercise_name.same_exercise("Lat Pull Down", "Lat Pulldown")


def test_canonical_distinct():
    assert not exercise_name.same_exercise("Bench Press", "Incline Bench Press")


# ---------------------------------------------------------------------------
# Rename endpoint
# ---------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_rename_preview_then_apply(async_client):
    device = str(uuid.uuid4())
    await async_client.post(
        "/api/v1/sessions",
        json=await create_session_payload(device, "2026-06-01", exercises=_ex("Lat Pulldown")),
    )
    await async_client.post(
        "/api/v1/sessions",
        json=await create_session_payload(device, "2026-06-05", exercises=_ex("Lat Pulldowns")),
    )

    # Preview (dry run) — canonical match catches the plural too.
    preview = await async_client.post(
        "/api/v1/exercises/rename",
        json={
            "device_uuid": device,
            "from_names": ["Lat Pulldown"],
            "to_name": "Lat Pulldown",
            "dry_run": True,
        },
    )
    assert preview.status_code == 200
    body = preview.json()
    # Only the plural differs from to_name, so exactly one occurrence is matched.
    assert body["matched_count"] == 1
    assert body["applied"] is False
    assert body["occurrences"][0]["old_name"] == "Lat Pulldowns"

    # Apply
    applied = await async_client.post(
        "/api/v1/exercises/rename",
        json={
            "device_uuid": device,
            "from_names": ["Lat Pulldown"],
            "to_name": "Lat Pulldown",
            "dry_run": False,
        },
    )
    assert applied.status_code == 200
    assert applied.json()["applied"] is True

    # Verify both sessions now read "Lat Pulldown"
    sessions = await async_client.get(f"/api/v1/sessions?device_uuid={device}")
    names = {ex["name"] for s in sessions.json() for ex in s["exercises"]}
    assert names == {"Lat Pulldown"}


@pytest.mark.asyncio
async def test_rename_merge_two_distinct_names(async_client):
    device = str(uuid.uuid4())
    await async_client.post(
        "/api/v1/sessions",
        json=await create_session_payload(device, "2026-06-01", exercises=_ex("Bent Over Row")),
    )
    await async_client.post(
        "/api/v1/sessions",
        json=await create_session_payload(device, "2026-06-05", exercises=_ex("Barbell Row")),
    )

    applied = await async_client.post(
        "/api/v1/exercises/rename",
        json={
            "device_uuid": device,
            "from_names": ["Bent Over Row", "Barbell Row"],
            "to_name": "Bent Over Barbell Row",
            "match": "exact",
            "dry_run": False,
        },
    )
    assert applied.status_code == 200
    assert applied.json()["matched_count"] == 2

    sessions = await async_client.get(f"/api/v1/sessions?device_uuid={device}")
    names = {ex["name"] for s in sessions.json() for ex in s["exercises"]}
    assert names == {"Bent Over Barbell Row"}


@pytest.mark.asyncio
async def test_suggest_name_single_returns_same(async_client):
    resp = await async_client.post(
        "/api/v1/exercises/suggest-name", json={"names": ["Bench Press"]}
    )
    assert resp.status_code == 200
    assert resp.json()["name"] == "Bench Press"


@pytest.mark.asyncio
async def test_parse_command_does_not_crash(async_client):
    # Real Gemini isn't available in tests, so this exercises the prompt
    # formatting + fallback path (it must not 500 on literal JSON braces).
    resp = await async_client.post(
        "/api/v1/exercises/parse-command",
        json={
            "device_uuid": str(uuid.uuid4()),
            "message": "rename all my lat pulldowns to Lat Pulldown",
            "known_names": ["Lat Pulldown", "Lat Pulldowns"],
        },
    )
    assert resp.status_code == 200
    body = resp.json()
    assert set(body.keys()) == {"is_rename", "from_names", "to_name"}


def test_rename_command_prompt_formats():
    # Guards against unescaped literal braces in the prompt template.
    from app.services.gemini_service import RENAME_COMMAND_PROMPT
    formatted = RENAME_COMMAND_PROMPT.format(known="- Bench Press")
    assert "is_rename" in formatted
    assert "- Bench Press" in formatted


@pytest.mark.asyncio
async def test_rename_invalid_device(async_client):
    resp = await async_client.post(
        "/api/v1/exercises/rename",
        json={"device_uuid": "not-a-uuid", "from_names": ["x"], "to_name": "y"},
    )
    assert resp.status_code == 422
