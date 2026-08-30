import Config

jwt_secret =
  if config_env() == :prod do
    System.get_env("JWT_SECRET") ||
      raise "environment variable JWT_SECRET is missing"
  else
    System.get_env("JWT_SECRET", "change-me")
  end

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise "environment variable DATABASE_URL is missing"

  config :stackbox, Stackbox.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise "environment variable SECRET_KEY_BASE is missing"

  System.get_env("TOKEN_ENCRYPTION_KEY") ||
    raise "environment variable TOKEN_ENCRYPTION_KEY is missing"

  host = System.get_env("PHX_HOST") || "localhost"
  port = String.to_integer(System.get_env("PORT") || "8000")

  config :stackbox, StackboxWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [ip: {0, 0, 0, 0, 0, 0, 0, 0}, port: port],
    secret_key_base: secret_key_base
end

# --- Application settings (ported from backend/app/config.py Settings) ---
config :stackbox, :settings,
  jwt_secret: jwt_secret,
  access_token_expire_minutes:
    String.to_integer(System.get_env("ACCESS_TOKEN_EXPIRE_MINUTES", "30")),
  refresh_token_expire_days: String.to_integer(System.get_env("REFRESH_TOKEN_EXPIRE_DAYS", "30")),
  openai_api_key: System.get_env("OPENAI_API_KEY", ""),
  openai_base_url: System.get_env("OPENAI_BASE_URL", ""),
  openai_model: System.get_env("OPENAI_MODEL", "gpt-4o-mini"),
  github_client_id: System.get_env("GITHUB_CLIENT_ID", ""),
  github_client_secret: System.get_env("GITHUB_CLIENT_SECRET", ""),
  github_oauth_redirect_uri:
    System.get_env("GITHUB_OAUTH_REDIRECT_URI", "http://localhost:8000/github/oauth/callback"),
  code_runner_url: System.get_env("CODE_RUNNER_URL", "http://localhost:3001"),
  code_runner_auth_token: System.get_env("CODE_RUNNER_AUTH_TOKEN", ""),
  ppt_worker_url: System.get_env("PPT_WORKER_URL", "http://localhost:3002"),
  ppt_worker_auth_token: System.get_env("PPT_WORKER_AUTH_TOKEN", ""),
  token_encryption_key: System.get_env("TOKEN_ENCRYPTION_KEY", ""),
  redis_url: System.get_env("REDIS_URL", "redis://localhost:6379"),
  redis_stream_prefix: System.get_env("REDIS_STREAM_PREFIX", "stackbox:events"),
  frontend_base_url: System.get_env("FRONTEND_BASE_URL", "http://localhost:3000"),
  cors_allowed_origins:
    System.get_env(
      "CORS_ALLOWED_ORIGINS",
      "http://localhost:3000,http://127.0.0.1:3000,http://localhost:3002,http://127.0.0.1:3002"
    )

config :stackbox, Stackbox.Guardian,
  issuer: "stackbox",
  secret_key: jwt_secret,
  allowed_algos: ["HS256"],
  verify_issuer: false
