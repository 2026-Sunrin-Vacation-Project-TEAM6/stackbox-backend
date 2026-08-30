defmodule Stackbox.Realtime do
  @moduledoc """
  Shared helpers for the realtime collaboration layer
  (`StackboxWeb.StackBoxChannel` and `Stackbox.Realtime.RedisSubscriber`).

  ## Interop approach

  The production realtime service is `web_worker` (Rust/Axum), which relays
  `doc_update`/`presence`/`code_result` messages through per-stack-box Redis
  Streams + consumer groups (`redis_stream.rs`): a client's message is
  `XADD`ed to `<redis_stream_prefix>:<stack_box_id>`, a per-room consumer
  task reads it via `XREADGROUP`, persists it to Postgres, and rebroadcasts
  it to that room's connected WebSocket clients.

  Replicating that *exactly* here would mean giving Elixir its own
  dynamically-started per-room Redis Streams consumer with independent
  `seq` bookkeeping — but `doc_updates.seq` is only unique per
  `stack_box_id` (see the migration), and web_worker's consumer computes
  its own in-memory `next_seq` starting from `MAX(seq)`. Two independent
  writers (web_worker's consumer and an Elixir consumer) racing to persist
  the same stream entry would either violate the unique constraint or,
  worse, silently diverge into duplicate rows with different `seq` values.
  Untangling that safely (e.g. making one side the sole persister, or
  moving `seq` allocation to a shared sequence) is bigger than this task's
  scope, so this codebase takes the explicitly-allowed alternative:

  Elixir's realtime layer is **self-contained and Phoenix-native**:
  `StackboxWeb.StackBoxChannel` persists directly to the same
  `doc_updates`/`canvas_presence` Postgres tables `web_worker` uses (so
  both services remain consistent at the data layer — a client reconnecting
  through either backend sees the same state) and fans out to same-node
  subscribers purely via Phoenix's own `broadcast/3`/`broadcast_from/3`.

  `notify/3` below is a *separate*, best-effort concern: cross-node fan-out
  for a horizontally-scaled Elixir deployment, using plain Redis Pub/Sub
  (`PUBLISH`/`PSUBSCRIBE`, a different primitive than web_worker's Streams,
  so this never collides with or duplicates web_worker's persistence).
  Local, same-node delivery never depends on Redis being reachable.
  """

  require Logger

  alias Stackbox.Settings

  @pubsub_infix ":pubsub:"

  def topic(stack_box_id), do: "stack_box:#{stack_box_id}"

  def redis_channel(stack_box_id) do
    Settings.get(:redis_stream_prefix) <> @pubsub_infix <> to_string(stack_box_id)
  end

  def redis_pattern, do: Settings.get(:redis_stream_prefix) <> @pubsub_infix <> "*"

  def pubsub_infix, do: @pubsub_infix

  @doc "Unique id for this BEAM node, used to let `RedisSubscriber` ignore its own echo."
  def node_id, do: Atom.to_string(node())

  @doc """
  Delivers `event`/`payload` to every subscriber of `stack_box_id`'s
  channel topic on this node (via `StackboxWeb.Endpoint.broadcast/3`) and
  best-effort notifies other nodes (via `notify/3`).

  Used by callers that aren't a `Phoenix.Channel` process themselves — e.g.
  `StackboxWeb.StackBoxController`'s REST fallback for appending a doc
  update — and so have no `socket` to call `broadcast/3`/`broadcast_from/3`
  on directly. `StackboxWeb.StackBoxChannel` calls `broadcast/3` and
  `notify/3` directly instead, since it needs the sender-inclusion choice
  (`broadcast/3` vs `broadcast_from/3`) that only exists on a socket.
  """
  def broadcast(stack_box_id, event, payload) do
    StackboxWeb.Endpoint.broadcast(topic(stack_box_id), event, payload)
    notify(stack_box_id, event, payload)
  end

  @doc """
  Best-effort cross-node notification: publishes `event`/`payload` for
  `stack_box_id` to Redis so any other Elixir node's `RedisSubscriber` can
  relay it to its own local channel subscribers. Never raises — if Redis is
  unreachable this logs and returns `:error`, since local delivery on the
  originating node already happened through the channel's own
  `broadcast/3` / `broadcast_from/3` and does not depend on this call.
  """
  def notify(stack_box_id, event, payload) do
    body = Jason.encode!(%{"event" => event, "payload" => payload, "origin_node" => node_id()})

    case Redix.command(Stackbox.Redix, ["PUBLISH", redis_channel(stack_box_id), body]) do
      {:ok, _subscriber_count} ->
        :ok

      {:error, reason} ->
        Logger.warning("Stackbox.Realtime.notify: redis publish failed: #{inspect(reason)}")
        :error
    end
  rescue
    error ->
      Logger.warning("Stackbox.Realtime.notify: redis publish raised: #{inspect(error)}")
      :error
  end
end
