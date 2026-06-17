"""Endpoint-level tests for the shared LLM budget and per-request input caps."""

import base64
import io
from unittest.mock import AsyncMock, patch

import pytest
from httpx import AsyncClient

from app.config import settings
from app.ratelimit import device_llm_limiter, global_llm_limiter

DEV_A = "AAAAAAAA-0000-0000-0000-00000000000A"
DEV_B = "BBBBBBBB-0000-0000-0000-00000000000B"


@pytest.fixture()
def llm_budget():
    """Give a test control of the shared limiters; restore afterwards."""
    dev_orig = device_llm_limiter.max_requests
    glob_orig = global_llm_limiter.max_requests
    device_llm_limiter.reset()
    global_llm_limiter.reset()
    yield device_llm_limiter, global_llm_limiter
    device_llm_limiter.max_requests = dev_orig
    global_llm_limiter.max_requests = glob_orig
    device_llm_limiter.reset()
    global_llm_limiter.reset()


def _parse_body(dev=DEV_A):
    return {"transcript": "bench press 225 3x12", "device_uuid": dev,
            "unit_preference": "lbs", "context": {}}


# --------------------------------------------------------------------------- #
# Shared budget: /parse + /assistant/chat draw from ONE per-device budget
# --------------------------------------------------------------------------- #
@pytest.mark.asyncio
async def test_budget_is_shared_across_endpoints(async_client: AsyncClient, llm_budget) -> None:
    device, _ = llm_budget
    device.max_requests = 2
    hdr = {"X-Device-UUID": DEV_A}

    with patch("app.services.gemini_service.answer_question",
               new_callable=AsyncMock, return_value="ok"):
        # Two /parse calls exhaust the shared device budget...
        assert (await async_client.post("/api/v1/parse", json=_parse_body(), headers=hdr)).status_code == 200
        assert (await async_client.post("/api/v1/parse", json=_parse_body(), headers=hdr)).status_code == 200
        # ...so /assistant/chat (same device) is now blocked too.
        chat = {"device_uuid": DEV_A, "message": "what's my bench PR?"}
        r = await async_client.post("/api/v1/assistant/chat", json=chat, headers=hdr)
        assert r.status_code == 429, r.text
        assert "retry-after" in {k.lower() for k in r.headers}


@pytest.mark.asyncio
async def test_budget_is_per_device(async_client: AsyncClient, llm_budget) -> None:
    device, _ = llm_budget
    device.max_requests = 1
    a = await async_client.post("/api/v1/parse", json=_parse_body(DEV_A), headers={"X-Device-UUID": DEV_A})
    a2 = await async_client.post("/api/v1/parse", json=_parse_body(DEV_A), headers={"X-Device-UUID": DEV_A})
    b = await async_client.post("/api/v1/parse", json=_parse_body(DEV_B), headers={"X-Device-UUID": DEV_B})
    assert a.status_code == 200
    assert a2.status_code == 429  # A exhausted
    assert b.status_code == 200   # B unaffected


# --------------------------------------------------------------------------- #
# Global ceiling: many devices collectively trip the wallet backstop
# --------------------------------------------------------------------------- #
@pytest.mark.asyncio
async def test_global_ceiling(async_client: AsyncClient, llm_budget) -> None:
    device, glob = llm_budget
    device.max_requests = 100  # not the constraint here
    glob.max_requests = 2
    r1 = await async_client.post("/api/v1/parse", json=_parse_body(DEV_A), headers={"X-Device-UUID": DEV_A})
    r2 = await async_client.post("/api/v1/parse", json=_parse_body(DEV_B), headers={"X-Device-UUID": DEV_B})
    r3 = await async_client.post("/api/v1/parse", json=_parse_body(DEV_A), headers={"X-Device-UUID": DEV_A})
    assert r1.status_code == 200
    assert r2.status_code == 200
    assert r3.status_code == 429  # global cap reached despite A being under its own limit


@pytest.mark.asyncio
async def test_global_block_does_not_charge_device(async_client: AsyncClient, llm_budget) -> None:
    """A request rejected by the global cap must not consume the device's allowance."""
    device, glob = llm_budget
    device.max_requests = 2
    glob.max_requests = 1
    hdr = {"X-Device-UUID": DEV_A}

    assert (await async_client.post("/api/v1/parse", json=_parse_body(), headers=hdr)).status_code == 200   # global=1, devA=1
    assert (await async_client.post("/api/v1/parse", json=_parse_body(), headers=hdr)).status_code == 429   # blocked by global

    glob.max_requests = 100  # lift the global cap
    # If the blocked request had charged the device, devA would already be at 2 -> this would 429.
    assert (await async_client.post("/api/v1/parse", json=_parse_body(), headers=hdr)).status_code == 200   # devA=2
    assert (await async_client.post("/api/v1/parse", json=_parse_body(), headers=hdr)).status_code == 429   # now devA exhausted


# --------------------------------------------------------------------------- #
# Per-request input caps
# --------------------------------------------------------------------------- #
@pytest.mark.asyncio
async def test_transcript_too_long_rejected(async_client: AsyncClient, llm_budget) -> None:
    body = _parse_body()
    body["transcript"] = "a" * (settings.MAX_TRANSCRIPT_CHARS + 1)
    r = await async_client.post("/api/v1/parse", json=body, headers={"X-Device-UUID": DEV_A})
    assert r.status_code == 422


@pytest.mark.asyncio
async def test_assistant_message_too_long_rejected(async_client: AsyncClient, llm_budget) -> None:
    body = {"device_uuid": DEV_A, "message": "a" * (settings.MAX_ASSISTANT_CHARS + 1)}
    r = await async_client.post("/api/v1/assistant/chat", json=body, headers={"X-Device-UUID": DEV_A})
    assert r.status_code == 422


@pytest.mark.asyncio
async def test_import_payload_too_large_rejected(
    async_client: AsyncClient, llm_budget, monkeypatch
) -> None:
    monkeypatch.setattr(settings, "MAX_IMPORT_BYTES", 16)  # tiny cap for the test
    payload = base64.b64encode(b"x" * 64).decode()  # decodes to 64 bytes > 16
    body = {"kind": "spreadsheet", "content_base64": payload}
    r = await async_client.post("/api/v1/import/preview", json=body, headers={"X-Device-UUID": DEV_A})
    assert r.status_code == 413


# --------------------------------------------------------------------------- #
# Import fan-out cap: one request must not spawn unbounded Gemini calls
# --------------------------------------------------------------------------- #
@pytest.mark.asyncio
async def test_import_fanout_capped(async_client: AsyncClient, llm_budget) -> None:
    from openpyxl import Workbook

    wb = Workbook()
    wb.remove(wb.active)
    n_sheets = settings.MAX_IMPORT_SHEETS + 5
    for i in range(n_sheets):
        ws = wb.create_sheet(title=f"P{i}")
        ws.append(["Exercise", "SETS", "REPS", "WEIGHT"])  # makes it "look like training"
        ws.append(["Bench Press", 3, 10, 135])
    buf = io.BytesIO()
    wb.save(buf)
    content = base64.b64encode(buf.getvalue()).decode()

    sheet_result = {
        "unit": "lbs",
        "workouts": [
            {"week": 1, "day": 1, "workout_type": "Push",
             "exercises": [{"name": "Bench Press", "sets": [{"reps": 10, "weight": 135.0}]}]}
        ],
    }
    mock = AsyncMock(return_value=sheet_result)
    with patch("app.services.gemini_service.extract_spreadsheet_sheet", mock):
        r = await async_client.post(
            "/api/v1/import/preview",
            json={"kind": "spreadsheet", "content_base64": content},
            headers={"X-Device-UUID": DEV_A},
        )
    assert r.status_code == 200, r.text
    assert mock.await_count == settings.MAX_IMPORT_SHEETS  # capped, not n_sheets
