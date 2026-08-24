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
