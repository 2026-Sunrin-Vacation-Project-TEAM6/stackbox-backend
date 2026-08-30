defmodule Stackbox.Repo do
  use Ecto.Repo,
    otp_app: :stackbox,
    adapter: Ecto.Adapters.Postgres
end
