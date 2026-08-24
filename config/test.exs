import Config

config :stackbox, Stackbox.Repo,
  url:
    System.get_env("DATABASE_URL") || "ecto://stackbox:stackbox@localhost:5432/stackbox_db_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

config :stackbox, StackboxWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: String.duplicate("a", 64),
  server: false

config :logger, level: :warning
