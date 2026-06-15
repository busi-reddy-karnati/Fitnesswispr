"""
Test configuration and fixtures.

Uses an in-memory SQLite database (aiosqlite) so tests don't need PostgreSQL.
Gemini API calls are patched at the router level to avoid real API calls.
"""
import asyncio
import uuid
from collections.abc import AsyncGenerator
from unittest.mock import AsyncMock, patch

import pytest
import pytest_asyncio
from fastapi import HTTPException
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import StaticPool

# ---------------------------------------------------------------------------
# Import Base and models FIRST so metadata is populated before create_all
# ---------------------------------------------------------------------------
import app.models  # noqa: F401  — registers all ORM tables with Base.metadata
from app.database import Base
from app.dependencies import get_db
from app.main import app as fastapi_app

# ---------------------------------------------------------------------------
# Fixed parsed workout returned by the mocked Gemini service
# ---------------------------------------------------------------------------
MOCK_PARSED_WORKOUT = {
    "workout_type": "Push",
    "body_weight_lbs": None,
    "cardio_notes": None,
    "session_notes": None,
    "duration_minutes": None,
    "exercises": [
        {
            "name": "Bench Press",
            "equipment": "barbell",
            "muscle_group": "chest",
            "notes": None,
            "exercise_order": 0,
            "sets": [
                {
                    "set_number": 1,
                    "reps": 10,
                    "weight": 135.0,
                    "weight_unit": "lbs",
                    "duration_seconds": None,
                },
                {
                    "set_number": 2,
                    "reps": 8,
                    "weight": 145.0,
                    "weight_unit": "lbs",
                    "duration_seconds": None,
                },
                {
                    "set_number": 3,
                    "reps": 6,
                    "weight": 155.0,
                    "weight_unit": "lbs",
                    "duration_seconds": None,
                },
            ],
        }
    ],
}

# ---------------------------------------------------------------------------
# SQLite in-memory engine (single shared DB for the test session)
# ---------------------------------------------------------------------------
TEST_DATABASE_URL = "sqlite+aiosqlite:///:memory:"

test_engine = create_async_engine(
    TEST_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,  # share a single connection across all sessions
    echo=False,
)

TestSessionLocal = async_sessionmaker(
    bind=test_engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autocommit=False,
    autoflush=False,
)


# ---------------------------------------------------------------------------
# Session-scoped: create tables once, drop at the end
# ---------------------------------------------------------------------------
@pytest_asyncio.fixture(scope="session", autouse=True)
async def create_tables():
    """Create all ORM tables in the SQLite test DB once per session."""
    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield
    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
    await test_engine.dispose()


# ---------------------------------------------------------------------------
# Per-test DB session
# ---------------------------------------------------------------------------
@pytest_asyncio.fixture()
async def db_session() -> AsyncGenerator[AsyncSession, None]:
    """Yield a fresh AsyncSession for each test; truncate tables after."""
    async with TestSessionLocal() as session:
        yield session
        await session.rollback()

    # Clean all rows between tests for isolation
    async with TestSessionLocal() as cleanup_session:
        for table in reversed(Base.metadata.sorted_tables):
            await cleanup_session.execute(table.delete())
        await cleanup_session.commit()


# ---------------------------------------------------------------------------
# Override the FastAPI get_db dependency with the test session
# ---------------------------------------------------------------------------
@pytest_asyncio.fixture()
async def async_client(db_session: AsyncSession) -> AsyncGenerator[AsyncClient, None]:
    """
    AsyncClient wired to the test DB.
    Gemini service is mocked to avoid real API calls.
    """

    async def override_get_db() -> AsyncGenerator[AsyncSession, None]:
        try:
            yield db_session
            await db_session.commit()
        except Exception:
            await db_session.rollback()
            raise

    fastapi_app.dependency_overrides[get_db] = override_get_db

    with patch(
        "app.services.gemini_service.parse_transcript",
        new_callable=AsyncMock,
        return_value=MOCK_PARSED_WORKOUT,
    ):
        async with AsyncClient(
            transport=ASGITransport(app=fastapi_app),
            base_url="http://test",
        ) as client:
            yield client

    fastapi_app.dependency_overrides.clear()


# ---------------------------------------------------------------------------
# Convenience fixture: async_client where Gemini raises parse_error 422
# ---------------------------------------------------------------------------
@pytest_asyncio.fixture()
async def async_client_parse_error(
    db_session: AsyncSession,
) -> AsyncGenerator[AsyncClient, None]:
    """AsyncClient where parse_transcript raises HTTPException(422)."""

    async def override_get_db() -> AsyncGenerator[AsyncSession, None]:
        yield db_session

    async def override_get_db_error() -> AsyncGenerator[AsyncSession, None]:
        try:
            yield db_session
            await db_session.commit()
        except Exception:
            await db_session.rollback()
            raise

    fastapi_app.dependency_overrides[get_db] = override_get_db_error

    async def _raise_422(*args, **kwargs):  # type: ignore[misc]
        raise HTTPException(
            status_code=422, detail="Could not understand the transcript"
        )

    with patch(
        "app.services.gemini_service.parse_transcript",
        side_effect=_raise_422,
    ):
        async with AsyncClient(
            transport=ASGITransport(app=fastapi_app),
            base_url="http://test",
        ) as client:
            yield client

    fastapi_app.dependency_overrides.clear()


# ---------------------------------------------------------------------------
# Helper: build a session creation payload
# ---------------------------------------------------------------------------
async def create_session_payload(
    device_uuid: str,
    workout_date: str = "2026-06-15",
    workout_type: str = "Push",
    exercises: list | None = None,
) -> dict:
    """Return a dict suitable for POST /api/v1/sessions."""
    if exercises is None:
        exercises = [
            {
                "name": "Bench Press",
                "equipment": "barbell",
                "muscle_group": "chest",
                "exercise_order": 0,
                "sets": [
                    {
                        "set_number": 1,
                        "reps": 10,
                        "weight": 135.0,
                        "weight_unit": "lbs",
                        "duration_seconds": None,
                    },
                    {
                        "set_number": 2,
                        "reps": 8,
                        "weight": 145.0,
                        "weight_unit": "lbs",
                        "duration_seconds": None,
                    },
                    {
                        "set_number": 3,
                        "reps": 6,
                        "weight": 155.0,
                        "weight_unit": "lbs",
                        "duration_seconds": None,
                    },
                ],
            }
        ]
    return {
        "device_uuid": device_uuid,
        "workout_date": workout_date,
        "workout_type": workout_type,
        "source": "voice",
        "exercises": exercises,
    }
