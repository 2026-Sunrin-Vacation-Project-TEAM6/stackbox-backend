import Config

config :stackbox,
  ecto_repos: [Stackbox.Repo]

config :stackbox, Stackbox.Repo,
  migration_timestamps: [type: :utc_datetime_usec]

config :stackbox, StackboxWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Phoenix.Endpoint.Cowboy2Adapter,
  render_errors: [
    formats: [json: StackboxWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Stackbox.PubSub,
  live_view: [signing_salt: "stackboxsalt"]

config :stackbox, Stackbox.Guardian,
  issuer: "stackbox",
  ttl: {30, :minutes}

config :phoenix, :json_library, Jason

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

import_config "#{config_env()}.exs"
