"""In-process sliding-window rate limiter.

Protects the expensive LLM-backed /parse endpoint from abuse. Requests are
keyed by device UUID (the X-Device-UUID header) and fall back to client IP
when the header is absent.

State is per-process, which is fine for the current single-worker
deployment. If the backend is ever scaled to multiple workers/instances,
swap the store for a shared backend (e.g. Redis) — the RateLimiter
interface can stay the same.
"""
from __future__ import annotations

import time
from collections import deque

from fastapi import HTTPException, Request

from app.config import settings


class RateLimiter:
    """Sliding-window log limiter: at most `max_requests` per `window_seconds`."""

    def __init__(
        self,
        max_requests: int,
        window_seconds: float,
        time_func=time.monotonic,
    ) -> None:
        self.max_requests = max_requests
        self.window_seconds = window_seconds
        self._time = time_func
        self._hits: dict[str, deque[float]] = {}

    def check(self, key: str) -> tuple[bool, float]:
        """Peek whether `key` is under the limit WITHOUT recording a request.

        Returns (allowed, retry_after_seconds). Prunes expired hits as a side
        effect, but does not consume an allowance — call `record()` for that.
        Splitting check/record lets a caller gate on several limiters and only
        consume them all when every one allows (no double-charging).
        """
        now = self._time()
        hits = self._hits.get(key)
        if hits is None:
            return True, 0.0

        cutoff = now - self.window_seconds
        while hits and hits[0] <= cutoff:
            hits.popleft()

        if len(hits) >= self.max_requests:
            retry_after = hits[0] + self.window_seconds - now
            return False, max(retry_after, 0.0)
        return True, 0.0

    def record(self, key: str) -> None:
        """Record a request for `key` (assumes `check` already passed)."""
        now = self._time()
        hits = self._hits.get(key)
        if hits is None:
            hits = deque()
            self._hits[key] = hits
        hits.append(now)

    def hit(self, key: str) -> tuple[bool, float]:
        """Convenience: check then record. Returns (allowed, retry_after)."""
        allowed, retry_after = self.check(key)
        if allowed:
            self.record(key)
        return allowed, retry_after

    def reset(self) -> None:
        """Clear all recorded hits (used by tests)."""
        self._hits.clear()


def client_key(request: Request) -> str:
    """Identify the caller: device UUID if provided, else client IP."""
    device = request.headers.get("X-Device-UUID")
    if device:
        return f"device:{device.lower()}"
    host = request.client.host if request.client else "unknown"
    return f"ip:{host}"


# --------------------------------------------------------------------------- #
# Shared LLM budget — one limiter for ALL Gemini-backed endpoints (so the
# per-device cap is a true total, not per-endpoint), plus a global ceiling
# across all callers as an absolute cost backstop.
# --------------------------------------------------------------------------- #
device_llm_limiter = RateLimiter(
    max_requests=settings.LLM_DAILY_LIMIT_PER_DEVICE,
    window_seconds=settings.LLM_RATE_WINDOW_SECONDS,
)
global_llm_limiter = RateLimiter(
    max_requests=settings.GLOBAL_LLM_DAILY_LIMIT,
    window_seconds=settings.LLM_RATE_WINDOW_SECONDS,
)
_GLOBAL_KEY = "global"


async def enforce_llm_budget(request: Request) -> None:
    """Gate every LLM endpoint on both the per-device and global daily budgets.

    Both limiters are *checked* first and only *recorded* when both allow, so a
    request rejected by one budget never consumes the other's allowance.
    """
    key = client_key(request)
    dev_ok, dev_retry = device_llm_limiter.check(key)
    glob_ok, glob_retry = global_llm_limiter.check(_GLOBAL_KEY)

    # Distinct, user-facing reasons so the app can tell the customer what
    # actually happened (their own daily cap vs. a temporary service-wide cap).
    if not dev_ok:
        raise HTTPException(
            status_code=429,
            detail=(
                f"You've reached your daily limit of "
                f"{settings.LLM_DAILY_LIMIT_PER_DEVICE} AI requests. "
                f"Please try again tomorrow."
            ),
            headers={"Retry-After": str(int(dev_retry) + 1)},
        )
    if not glob_ok:
        raise HTTPException(
            status_code=429,
            detail="SpotRep is busy right now. Please try again in a little while.",
            headers={"Retry-After": str(int(glob_retry) + 1)},
        )

    device_llm_limiter.record(key)
    global_llm_limiter.record(_GLOBAL_KEY)
