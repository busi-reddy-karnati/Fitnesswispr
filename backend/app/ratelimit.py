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

    def hit(self, key: str) -> tuple[bool, float]:
        """Record a request for `key`.

        Returns (allowed, retry_after_seconds). When not allowed, the request
        is NOT recorded and retry_after_seconds tells the caller how long until
        the oldest hit in the window expires.
        """
        now = self._time()
        hits = self._hits.get(key)
        if hits is None:
            hits = deque()
            self._hits[key] = hits

        cutoff = now - self.window_seconds
        while hits and hits[0] <= cutoff:
            hits.popleft()

        if len(hits) >= self.max_requests:
            retry_after = hits[0] + self.window_seconds - now
            return False, max(retry_after, 0.0)

        hits.append(now)
        # Drop the key's bookkeeping is left in place; empty deques are pruned
        # lazily on the next hit for that key.
        return True, 0.0

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


def make_rate_limit_dependency(limiter: RateLimiter):
    """Build a FastAPI dependency that enforces `limiter`, returning 429."""

    async def _enforce(request: Request) -> None:
        allowed, retry_after = limiter.hit(client_key(request))
        if not allowed:
            raise HTTPException(
                status_code=429,
                detail="Too many requests. Please slow down and try again shortly.",
                headers={"Retry-After": str(int(retry_after) + 1)},
            )

    return _enforce
