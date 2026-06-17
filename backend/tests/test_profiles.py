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
async def test_grant_register_list_revoke(async_client: AsyncClient) -> None:
    owner = str(uuid.uuid4())
    grantee = str(uuid.uuid4())

    # Grantee registers a grant after redeeming an invite.
    post = await async_client.post(
        f"/api/v1/profile/{owner}/grants",
        json={"grantee_uuid": grantee, "access": "write", "grantee_name": "Amit"},
    )
    assert post.status_code == 201, post.text
    assert post.json()["access"] == "write"

    # Owner sees who has access.
    grants = await async_client.get(f"/api/v1/profile/{owner}/grants")
    assert grants.status_code == 200
    body = grants.json()
    assert len(body) == 1
    assert body[0]["grantee_uuid"] == grantee
    assert body[0]["grantee_name"] == "Amit"

    # Grantee sees who they're spotting.
    spotting = await async_client.get(f"/api/v1/profile/{grantee}/spotting")
    assert spotting.status_code == 200
    assert [s["owner_uuid"] for s in spotting.json()] == [owner]

    # Owner revokes.
    rev = await async_client.delete(f"/api/v1/profile/{owner}/grants/{grantee}")
    assert rev.status_code == 204

    # Now gone from both views.
    assert (await async_client.get(f"/api/v1/profile/{owner}/grants")).json() == []
    assert (await async_client.get(f"/api/v1/profile/{grantee}/spotting")).json() == []


@pytest.mark.asyncio
async def test_grant_is_deduped_on_reregister(async_client: AsyncClient) -> None:
    owner = str(uuid.uuid4())
    grantee = str(uuid.uuid4())
    for access in ("read", "write", "read"):
        r = await async_client.post(
            f"/api/v1/profile/{owner}/grants",
            json={"grantee_uuid": grantee, "access": access},
        )
        assert r.status_code == 201
    grants = (await async_client.get(f"/api/v1/profile/{owner}/grants")).json()
    assert len(grants) == 1           # re-registering updates, never duplicates
    assert grants[0]["access"] == "read"


@pytest.mark.asyncio
async def test_grant_to_self_rejected(async_client: AsyncClient) -> None:
    me = str(uuid.uuid4())
    r = await async_client.post(
        f"/api/v1/profile/{me}/grants", json={"grantee_uuid": me}
    )
    assert r.status_code == 422


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
