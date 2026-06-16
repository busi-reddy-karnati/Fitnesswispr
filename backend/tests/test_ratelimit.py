"""Tests for the /parse rate limiter."""

import pytest
from httpx import AsyncClient

from app.config import settings
from app.ratelimit import RateLimiter
from app.routers import parse as parse_router


# ---------------------------------------------------------------------------
# Configured limit: 100 requests per rolling 24h
# ---------------------------------------------------------------------------
def test_parse_limit_is_100_per_day() -> None:
    assert settings.PARSE_RATE_LIMIT == 100
    assert settings.PARSE_RATE_WINDOW_SECONDS == 86400
    assert parse_router.parse_limiter.window_seconds == 86400


# ---------------------------------------------------------------------------
# Unit tests for the RateLimiter (deterministic via an injected clock)
# ---------------------------------------------------------------------------
def test_allows_up_to_limit_then_blocks() -> None:
    clock = [0.0]
    rl = RateLimiter(max_requests=3, window_seconds=60, time_func=lambda: clock[0])

    assert rl.hit("k") == (True, 0.0)
    assert rl.hit("k")[0] is True
    assert rl.hit("k")[0] is True

    allowed, retry_after = rl.hit("k")
    assert allowed is False
    assert retry_after > 0


def test_window_slides_and_allows_again() -> None:
    clock = [0.0]
    rl = RateLimiter(max_requests=2, window_seconds=10, time_func=lambda: clock[0])

    assert rl.hit("k")[0] is True
    assert rl.hit("k")[0] is True
    assert rl.hit("k")[0] is False  # limit hit

    clock[0] = 10.5  # advance past the window
    assert rl.hit("k")[0] is True  # oldest hits expired -> allowed


def test_keys_are_independent() -> None:
    clock = [0.0]
    rl = RateLimiter(max_requests=1, window_seconds=60, time_func=lambda: clock[0])

    assert rl.hit("device:a")[0] is True
    assert rl.hit("device:a")[0] is False  # a is limited
    assert rl.hit("device:b")[0] is True  # b unaffected


def test_blocked_request_is_not_counted() -> None:
    """A rejected hit must not extend the window (no penalty stacking)."""
    clock = [0.0]
    rl = RateLimiter(max_requests=1, window_seconds=10, time_func=lambda: clock[0])

    assert rl.hit("k")[0] is True
    assert rl.hit("k")[0] is False
    clock[0] = 10.1
    # Only the first (allowed) hit counted, so it has now expired.
    assert rl.hit("k")[0] is True


# ---------------------------------------------------------------------------
# Integration: /parse returns 429 once the limit is exceeded
# ---------------------------------------------------------------------------
@pytest.fixture()
def tight_parse_limit():
    """Temporarily shrink the parse limiter so the endpoint trips quickly."""
    limiter = parse_router.parse_limiter
    original = limiter.max_requests
    limiter.max_requests = 2
    limiter.reset()
    yield
    limiter.max_requests = original
    limiter.reset()


@pytest.mark.asyncio
async def test_parse_rate_limited(async_client: AsyncClient, tight_parse_limit) -> None:
    payload = {
        "transcript": "bench press 225 for 3 sets of 12",
        "device_uuid": "00000000-0000-0000-0000-000000000009",
        "unit_preference": "lbs",
        "context": {},
    }
    headers = {"X-Device-UUID": "00000000-0000-0000-0000-000000000009"}

    r1 = await async_client.post("/api/v1/parse", json=payload, headers=headers)
    r2 = await async_client.post("/api/v1/parse", json=payload, headers=headers)
    r3 = await async_client.post("/api/v1/parse", json=payload, headers=headers)

    assert r1.status_code == 200, r1.text
    assert r2.status_code == 200, r2.text
    assert r3.status_code == 429, r3.text
    assert "retry-after" in {k.lower() for k in r3.headers}


@pytest.mark.asyncio
async def test_parse_rate_limit_is_per_device(
    async_client: AsyncClient, tight_parse_limit
) -> None:
    """One device hitting the limit must not block a different device."""
    body = {
        "transcript": "squat 315 for 5 reps, 3 sets",
        "device_uuid": "ignored-uses-header",
        "unit_preference": "lbs",
        "context": {},
    }
    dev_a = {"X-Device-UUID": "AAAAAAAA-0000-0000-0000-00000000000A"}
    dev_b = {"X-Device-UUID": "BBBBBBBB-0000-0000-0000-00000000000B"}

    assert (await async_client.post("/api/v1/parse", json=body, headers=dev_a)).status_code == 200
    assert (await async_client.post("/api/v1/parse", json=body, headers=dev_a)).status_code == 200
    assert (await async_client.post("/api/v1/parse", json=body, headers=dev_a)).status_code == 429

    # Different device still has its full allowance.
    assert (await async_client.post("/api/v1/parse", json=body, headers=dev_b)).status_code == 200
