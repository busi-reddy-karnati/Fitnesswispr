from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    GEMINI_API_KEY: str = "placeholder"
    DATABASE_URL: str = "postgresql+asyncpg://postgres:postgres@localhost/fitnesswispr"
    CORS_ORIGINS: list[str] = ["*"]


settings = Settings()
