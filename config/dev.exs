import Config

config :stackbox, Stackbox.Repo,
  url: System.get_env("DATABASE_URL") || "ecto://stackbox:stackbox@localhost:5432/stackbox_db",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :stackbox, StackboxWeb.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: String.to_integer(System.get_env("PORT") || "8000")],
  check_origin: false,
  debug_errors: true,
  secret_key_base: System.get_env("SECRET_KEY_BASE") || String.duplicate("a", 64)

config :logger, :console, format: "[$level] $message\n"

config :stackbox, dev_routes: true
