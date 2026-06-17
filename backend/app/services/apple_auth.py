"""Verification of Sign in with Apple identity tokens.

Apple signs the identity token (a JWT) with rotating RS256 keys published at
their JWKS endpoint. We fetch and cache those keys, then verify the token's
signature, issuer, audience and expiry.
"""
import time
from dataclasses import dataclass

import httpx
import jwt
from fastapi import HTTPException
from jwt.algorithms import RSAAlgorithm

from app.config import settings

# Cache Apple's public keys to avoid fetching on every sign-in.
_jwks_cache: dict[str, object] = {}
_jwks_fetched_at: float = 0.0
_JWKS_TTL_SECONDS = 60 * 60  # refresh hourly


@dataclass
class AppleIdentity:
    sub: str
    email: str | None


async def _get_apple_keys() -> dict[str, object]:
    global _jwks_cache, _jwks_fetched_at
    now = time.time()
    if _jwks_cache and (now - _jwks_fetched_at) < _JWKS_TTL_SECONDS:
        return _jwks_cache

    async with httpx.AsyncClient(timeout=10) as client:
        resp = await client.get(settings.APPLE_JWKS_URL)
        resp.raise_for_status()
        data = resp.json()

    keys = {key["kid"]: RSAAlgorithm.from_jwk(key) for key in data.get("keys", [])}
    _jwks_cache = keys
    _jwks_fetched_at = now
    return keys


async def verify_identity_token(identity_token: str) -> AppleIdentity:
    """Validate an Apple identity token and return the verified identity.

    Raises HTTPException(401) if the token is missing, malformed, or invalid.
    """
    if not identity_token:
        raise HTTPException(status_code=401, detail="Missing Apple identity token")

    try:
        header = jwt.get_unverified_header(identity_token)
    except jwt.PyJWTError:
        raise HTTPException(status_code=401, detail="Malformed Apple identity token")

    kid = header.get("kid")
    keys = await _get_apple_keys()
    key = keys.get(kid)
    if key is None:
        # Key may have rotated; force a refresh once.
        _jwks_cache.clear()
        keys = await _get_apple_keys()
        key = keys.get(kid)
    if key is None:
        raise HTTPException(status_code=401, detail="Unknown Apple signing key")

    try:
        claims = jwt.decode(
            identity_token,
            key=key,
            algorithms=["RS256"],
            audience=settings.APPLE_BUNDLE_ID,
            issuer=settings.APPLE_ISSUER,
        )
    except jwt.PyJWTError as exc:
        raise HTTPException(status_code=401, detail=f"Invalid Apple identity token: {exc}")

    sub = claims.get("sub")
    if not sub:
        raise HTTPException(status_code=401, detail="Apple token missing subject")

    return AppleIdentity(sub=sub, email=claims.get("email"))
