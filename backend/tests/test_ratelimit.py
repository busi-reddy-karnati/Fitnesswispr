"""Unit tests for the RateLimiter primitive (deterministic via injected clock)."""

from app.config import settings
from app.ratelimit import RateLimiter, device_llm_limiter, global_llm_limiter


def test_llm_budget_config() -> None:
    assert settings.LLM_DAILY_LIMIT_PER_DEVICE == 100
    assert settings.GLOBAL_LLM_DAILY_LIMIT == 5000
    assert settings.LLM_RATE_WINDOW_SECONDS == 86400
    assert device_llm_limiter.window_seconds == 86400
    assert global_llm_limiter.window_seconds == 86400


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
    assert rl.hit("k")[0] is True  # only the first (allowed) hit counted


def test_check_does_not_consume_record_does() -> None:
    """check() peeks without consuming; record() consumes."""
    clock = [0.0]
    rl = RateLimiter(max_requests=1, window_seconds=60, time_func=lambda: clock[0])

    # check() can be called repeatedly without ever consuming the allowance.
    assert rl.check("k")[0] is True
    assert rl.check("k")[0] is True
    rl.record("k")
    # Now the single allowance is gone.
    assert rl.check("k")[0] is False
