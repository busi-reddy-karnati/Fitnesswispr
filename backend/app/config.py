from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    GEMINI_API_KEY: str = "placeholder"
    DATABASE_URL: str = "postgresql+asyncpg://postgres:postgres@localhost/fitnesswispr"
    CORS_ORIGINS: list[str] = ["*"]

    # Rate limit for the LLM-backed /parse endpoint (per device UUID, or IP
    # when the X-Device-UUID header is absent). 100 requests per rolling 24h.
    PARSE_RATE_LIMIT: int = 100
    PARSE_RATE_WINDOW_SECONDS: int = 86400  # 24 hours


settings = Settings()
