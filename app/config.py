from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    database_url: str = "postgresql+psycopg2://stackbox:stackbox@localhost:5432/stackbox_db"

    jwt_secret: str = "change-me"
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 30
    refresh_token_expire_days: int = 30

    openai_api_key: str = ""
    openai_base_url: str = ""
    openai_model: str = "gpt-4o-mini"

    github_client_id: str = ""
    github_client_secret: str = ""
    github_oauth_redirect_uri: str = "http://localhost:8000/github/oauth/callback"

    code_runner_url: str = "http://localhost:3001"
    code_runner_auth_token: str = ""
    token_encryption_key: str = ""

    redis_url: str = "redis://localhost:6379"
    redis_stream_prefix: str = "stackbox:events"
    frontend_base_url: str = "http://localhost:3000"


settings = Settings()
