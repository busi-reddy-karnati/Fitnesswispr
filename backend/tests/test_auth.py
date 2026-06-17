"""Tests for /api/v1/auth/apple (Sign in with Apple).

The Apple identity-token verification is patched so tests don't hit Apple.
"""
import uuid
from unittest.mock import patch

import pytest
from httpx import AsyncClient

from app.services.apple_auth import AppleIdentity
from tests.conftest import create_session_payload


def _patch_apple(sub: str, email: str | None = "user@example.com"):
    return patch(
        "app.routers.auth.verify_identity_token",
        return_value=AppleIdentity(sub=sub, email=email),
    )


@pytest.mark.asyncio
async def test_first_sign_in_claims_local_uuid(async_client: AsyncClient) -> None:
    """First sign-in creates the account and adopts the device's local UUID."""
    local = str(uuid.uuid4())
    with _patch_apple("apple-sub-1"):
        resp = await async_client.post(
            "/api/v1/auth/apple",
            json={"identity_token": "tok", "device_uuid": local},
        )
    assert resp.status_code == 200, resp.text
    data = resp.json()
    assert data["is_new"] is True
    assert data["primary_uuid"] == local
    assert data["token"]


@pytest.mark.asyncio
async def test_returning_user_gets_same_primary_uuid(async_client: AsyncClient) -> None:
    """Signing in again (even from a new device) returns the canonical UUID."""
    first_device = str(uuid.uuid4())
    with _patch_apple("apple-sub-2"):
        r1 = await async_client.post(
            "/api/v1/auth/apple",
            json={"identity_token": "tok", "device_uuid": first_device},
        )
    primary = r1.json()["primary_uuid"]

    # New device signs in with the same Apple account.
    new_device = str(uuid.uuid4())
    with _patch_apple("apple-sub-2"):
        r2 = await async_client.post(
            "/api/v1/auth/apple",
            json={"identity_token": "tok", "device_uuid": new_device},
        )
    data = r2.json()
    assert data["is_new"] is False
    assert data["primary_uuid"] == primary


@pytest.mark.asyncio
async def test_new_device_data_merged_into_account(async_client: AsyncClient) -> None:
    """Anonymous data on a new device is merged into the account on sign-in."""
    # Account created on device A.
    device_a = str(uuid.uuid4())
    with _patch_apple("apple-sub-3"):
        r1 = await async_client.post(
            "/api/v1/auth/apple",
            json={"identity_token": "tok", "device_uuid": device_a},
        )
    primary = r1.json()["primary_uuid"]

    # On device B, the user logs a workout anonymously first.
    device_b = str(uuid.uuid4())
    payload = await create_session_payload(device_b, workout_date="2026-06-12")
    cr = await async_client.post("/api/v1/sessions", json=payload)
    assert cr.status_code == 201

    # Then signs in on device B -> its workout should move to the account.
    with _patch_apple("apple-sub-3"):
        await async_client.post(
            "/api/v1/auth/apple",
            json={"identity_token": "tok", "device_uuid": device_b},
        )

    listing = await async_client.get(
        "/api/v1/sessions", params={"device_uuid": primary}
    )
    assert listing.status_code == 200
    dates = [s["workout_date"] for s in listing.json()]
    assert "2026-06-12" in dates
