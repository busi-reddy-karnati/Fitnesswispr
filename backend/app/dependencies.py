import logging
from typing import AsyncGenerator

from app.database import AsyncSessionLocal
from sqlalchemy.ext.asyncio import AsyncSession

logger = logging.getLogger(__name__)


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            logger.exception("Database session error; rolling back transaction")
            await session.rollback()
            raise
        finally:
            await session.close()
