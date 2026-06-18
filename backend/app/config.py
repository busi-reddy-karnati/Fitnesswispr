from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    GEMINI_API_KEY: str = "placeholder"
    DATABASE_URL: str = "postgresql+asyncpg://postgres:postgres@localhost/fitnesswispr"
    CORS_ORIGINS: list[str] = ["*"]

    # --- LLM abuse / cost controls -------------------------------------- #
    # One budget shared across all LLM endpoints (/parse, /assistant/chat,
    # /import/preview), keyed by device UUID (or client IP as fallback), plus a
    # global ceiling across all callers as an absolute wallet backstop.
    LLM_DAILY_LIMIT_PER_DEVICE: int = 100
    GLOBAL_LLM_DAILY_LIMIT: int = 5000
    LLM_RATE_WINDOW_SECONDS: int = 86400  # rolling 24h

    # Per-request input caps (reject before spending Gemini tokens).
    MAX_TRANSCRIPT_CHARS: int = 2000
    MAX_ASSISTANT_CHARS: int = 1000
    MAX_IMPORT_BYTES: int = 8 * 1024 * 1024  # 8 MB decoded upload
    MAX_IMPORT_SHEETS: int = 12  # cap concurrent Gemini calls per import

    # Per-call Gemini output caps. Keep generous: with JSON responses a
    # truncated output is invalid JSON, so these must fit real outputs.
    PARSE_MAX_OUTPUT_TOKENS: int = 2048
    ASSISTANT_MAX_OUTPUT_TOKENS: int = 600
    IMPORT_MAX_OUTPUT_TOKENS: int = 8192

    # --- Payload size limits (DB/memory abuse on non-LLM endpoints) ------ #
    # Reject absurdly large writes before they bloat the DB or memory.
    MAX_REQUEST_BODY_BYTES: int = 12 * 1024 * 1024  # > the largest legit import body
    MAX_EXERCISES_PER_SESSION: int = 50
    MAX_SETS_PER_EXERCISE: int = 50
    MAX_COMMIT_ITEMS: int = 500  # workouts per bulk import commit

    # Sign in with Apple. APPLE_BUNDLE_ID is the audience ("aud") of the
    # identity token issued to the native iOS app.
    APPLE_BUNDLE_ID: str = "com.fitnesswispr.app"
    APPLE_ISSUER: str = "https://appleid.apple.com"
    APPLE_JWKS_URL: str = "https://appleid.apple.com/auth/keys"

    # Secret used to sign our own session tokens returned after sign-in.
    JWT_SECRET: str = "dev-insecure-change-me-please-set-a-real-secret"
    JWT_ALGORITHM: str = "HS256"
    JWT_EXPIRE_DAYS: int = 365


settings = Settings()
