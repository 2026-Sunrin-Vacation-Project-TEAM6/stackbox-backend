defmodule Stackbox.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      StackboxWeb.Telemetry,
      Stackbox.Repo,
      {Phoenix.PubSub, name: Stackbox.PubSub},
      {Registry, keys: :unique, name: Stackbox.Realtime.RoomRegistry},
      {DynamicSupervisor, name: Stackbox.Realtime.RoomSupervisor, strategy: :one_for_one},
      %{
        id: Stackbox.Redix,
        start: {Redix, :start_link, [Stackbox.Settings.get(:redis_url), [name: Stackbox.Redix]]}
      },
      # Relays cross-node realtime notifications (see `Stackbox.Realtime`'s
      # moduledoc for the interop rationale). Previously this entry
      # referenced a module that didn't exist yet, which crashed
      # application boot (`UndefinedFunctionError` on `child_spec/1`) —
      # `Stackbox.Realtime.RedisSubscriber` now exists and fails gracefully
      # (logs and keeps running) instead of crashing if Redis is
      # unreachable, so it's safe to supervise unconditionally.
      Stackbox.Realtime.RedisSubscriber,
      StackboxWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Stackbox.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    StackboxWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
