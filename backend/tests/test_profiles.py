"""Tests for profile avatar upload/fetch."""
import uuid

import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_avatar_round_trip(async_client: AsyncClient) -> None:
    device = str(uuid.uuid4())
    payload = b"\xff\xd8\xff\xe0fakejpegbytes"

    put = await async_client.put(
        f"/api/v1/profile/{device}/avatar",
        content=payload,
        headers={"Content-Type": "image/jpeg"},
    )
    assert put.status_code == 204, put.text

    get = await async_client.get(f"/api/v1/profile/{device}/avatar")
    assert get.status_code == 200
    assert get.content == payload
    assert get.headers["content-type"] == "image/jpeg"


@pytest.mark.asyncio
async def test_profile_name_round_trip(async_client: AsyncClient) -> None:
    device = str(uuid.uuid4())
    # Unknown profile reads as empty, not an error.
    g0 = await async_client.get(f"/api/v1/profile/{device}")
    assert g0.status_code == 200
    assert g0.json()["name"] is None

    put = await async_client.put(f"/api/v1/profile/{device}", json={"name": "Kratika"})
    assert put.status_code == 200
    assert put.json()["name"] == "Kratika"

    # A name change is reflected on the next read (what a spotter fetches).
    await async_client.put(f"/api/v1/profile/{device}", json={"name": "Kratika S"})
    g1 = await async_client.get(f"/api/v1/profile/{device}")
    assert g1.json()["name"] == "Kratika S"


@pytest.mark.asyncio
async def test_avatar_missing_is_404(async_client: AsyncClient) -> None:
    device = str(uuid.uuid4())
    get = await async_client.get(f"/api/v1/profile/{device}/avatar")
    assert get.status_code == 404


@pytest.mark.asyncio
async def test_avatar_overwrite(async_client: AsyncClient) -> None:
    device = str(uuid.uuid4())
    await async_client.put(
        f"/api/v1/profile/{device}/avatar", content=b"first",
        headers={"Content-Type": "image/jpeg"},
    )
    await async_client.put(
        f"/api/v1/profile/{device}/avatar", content=b"second",
        headers={"Content-Type": "image/jpeg"},
    )
    get = await async_client.get(f"/api/v1/profile/{device}/avatar")
    assert get.content == b"second"
