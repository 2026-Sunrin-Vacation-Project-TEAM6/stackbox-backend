defmodule Stackbox.Realtime.RedisSubscriber do
  @moduledoc """
  Subscribes to the Redis Pub/Sub pattern `<redis_stream_prefix>:pubsub:*`
  and relays messages published by `Stackbox.Realtime.notify/3` (from any
  Elixir node) into this node's Phoenix Channel subscribers via
  `StackboxWeb.Endpoint.broadcast/3`.

  See `Stackbox.Realtime`'s moduledoc for why this uses classic Redis
  Pub/Sub rather than the Streams + consumer-group API `web_worker` uses
  for `doc_updates`/`canvas_presence` persistence: this module never
  persists anything, so it can't create the double-write hazard that a
  competing Streams consumer would.

  Boot safety: `Redix.PubSub.start_link/1` starts its connection process
  asynchronously and manages its own reconnect-with-backoff loop — it does
  not raise or block waiting on Redis being reachable. So if Redis is down
  at boot, `init/1` still returns `{:ok, state}` (this GenServer starts
  fine and the Redix.PubSub connection retries in the background); the
  previous version of this supervision entry crashed application boot by
  referencing a module (`Stackbox.Realtime.RedisSubscriber`) that plain
  didn't exist yet (`UndefinedFunctionError` on `child_spec/1`), which is a
  different failure mode than "Redis is unreachable."
  """

  use GenServer
  require Logger

  alias Stackbox.Realtime

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  @impl true
  def init(_opts) do
    redis_url = Stackbox.Settings.get(:redis_url)

    case Redix.PubSub.start_link(redis_url, sync_connect: false) do
      {:ok, pubsub} ->
        pattern = Realtime.redis_pattern()
        {:ok, _ref} = Redix.PubSub.psubscribe(pubsub, pattern, self())
        {:ok, %{pubsub: pubsub, pattern: pattern}}

      {:error, reason} ->
        Logger.warning(
          "Stackbox.Realtime.RedisSubscriber: could not start Redis pub/sub connection " <>
            "(#{inspect(reason)}); realtime cross-node relay is disabled, local " <>
            "same-node channel delivery is unaffected"
        )

        {:ok, %{pubsub: nil, pattern: nil}}
    end
  end

  @impl true
  def handle_info({:redix_pubsub, _pid, _ref, :psubscribed, %{pattern: pattern}}, state) do
    Logger.info("Stackbox.Realtime.RedisSubscriber: subscribed to #{pattern}")
    {:noreply, state}
  end

  def handle_info(
        {:redix_pubsub, _pid, _ref, :pmessage, %{channel: channel, payload: payload}},
        state
      ) do
    relay(channel, payload)
    {:noreply, state}
  end

  def handle_info({:redix_pubsub, _pid, _ref, :disconnected, %{error: error}}, state) do
    Logger.warning(
      "Stackbox.Realtime.RedisSubscriber: disconnected from redis (#{Exception.message(error)}); " <>
        "will retry automatically"
    )

    {:noreply, state}
  end

  def handle_info(_other, state), do: {:noreply, state}

  # Ignores messages this same node published (it already delivered them to
  # its own channel subscribers synchronously via broadcast/broadcast_from),
  # so a message is never pushed to a client twice.
  defp relay(channel, payload) do
    with {:ok, stack_box_id} <- extract_stack_box_id(channel),
         {:ok, %{"event" => event, "payload" => event_payload, "origin_node" => origin}} <-
           Jason.decode(payload),
         true <- origin != Realtime.node_id() do
      StackboxWeb.Endpoint.broadcast(Realtime.topic(stack_box_id), event, event_payload)
    else
      _ -> :ok
    end
  end

  defp extract_stack_box_id(channel) do
    case String.split(channel, Realtime.pubsub_infix()) do
      [_prefix, id_str] ->
        case Integer.parse(id_str) do
          {id, ""} -> {:ok, id}
          _ -> :error
        end

      _ ->
        :error
    end
  end
end
