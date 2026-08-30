defmodule StackboxWeb.StackBoxChannel do
  @moduledoc """
  Realtime collaboration channel for a single stack box: `"stack_box:<id>"`.

  Mirrors `web_worker`'s `/ws/{stack_box_id}` room (see
  `web_worker/src/main.rs`, `web_worker/src/redis_stream.rs`): a joining
  client gets a presence snapshot from the `canvas_presence` table, cursor
  updates are broadcast to other members with the sender's `user_id`
  stamped in server-side, and doc updates (Yjs-format binary CRDT updates,
  base64 over the wire like `doc_updates.blob`) are persisted with a
  server-computed `seq` and rebroadcast.

  `socket.assigns.current_user` is set once in `StackboxWeb.UserSocket.connect/3`
  from a verified Guardian token and is never re-derived from anything a
  client sends on this channel, so `user_id` here is always the
  authenticated connection's id — the same discipline `web_worker` applies
  (see `auth::verify_token` + `message::stamp_presence_sender`, which
  discards any client-sent `user_id` before broadcasting).
  """

  use StackboxWeb, :channel

  alias Stackbox.Authorization
  alias Stackbox.Realtime
  alias Stackbox.StackBoxes
  alias Stackbox.StackBoxes.StackBox

  @presence_fields ["cursor_x", "cursor_y", "selection", "color"]

  @impl true
  def join("stack_box:" <> stack_box_id_str, _payload, socket) do
    current_user = socket.assigns.current_user

    with {:ok, stack_box_id} <- parse_id(stack_box_id_str),
         %StackBox{} = stack_box <- StackBoxes.get_stack_box(stack_box_id),
         {:ok, _role} <-
           Authorization.require_workspace_role(stack_box.workspace_id, current_user, :viewer) do
      send(self(), :after_join)
      {:ok, assign(socket, :stack_box_id, stack_box_id)}
    else
      nil -> {:error, %{reason: "not_found"}}
      {:error, :forbidden} -> {:error, %{reason: "forbidden"}}
      :error -> {:error, %{reason: "not_found"}}
    end
  end

  @impl true
  def handle_info(:after_join, socket) do
    presences =
      socket.assigns.stack_box_id
      |> StackBoxes.list_canvas_presence()
      |> Enum.map(&presence_json/1)

    push(socket, "presence_snapshot", %{presences: presences})
    {:noreply, socket}
  end

  @impl true
  def handle_in("presence", payload, socket) do
    stack_box_id = socket.assigns.stack_box_id
    # `user_id` is stamped from the authenticated socket, never accepted
    # from `payload` — matches web_worker's `stamp_presence_sender`, which
    # overwrites (never trusts) any client-sent user_id before broadcast.
    user_id = socket.assigns.current_user.id

    attrs =
      payload
      |> Map.take(@presence_fields)
      |> atomize_keys()

    case StackBoxes.upsert_canvas_presence(stack_box_id, user_id, attrs) do
      {:ok, presence} ->
        payload = presence_json(presence)
        broadcast_from(socket, "presence", payload)
        Realtime.notify(stack_box_id, "presence", payload)
        {:noreply, socket}

      {:error, _changeset} ->
        {:reply, {:error, %{reason: "invalid_presence"}}, socket}
    end
  end

  def handle_in("doc_update", %{"blob" => blob}, socket) when is_binary(blob) do
    stack_box_id = socket.assigns.stack_box_id
    current_user = socket.assigns.current_user

    with {:ok, stack_box} <- fetch_stack_box(stack_box_id),
         {:ok, _role} <-
           Authorization.require_workspace_role(stack_box.workspace_id, current_user, :editor),
         {:ok, blob_bin} <- Base.decode64(blob) |> ok_or(:invalid_blob),
         {:ok, update} <- StackBoxes.append_doc_update(stack_box_id, blob_bin, current_user.id) do
      payload = doc_update_json(update)
      broadcast(socket, "doc_update", payload)
      Realtime.notify(stack_box_id, "doc_update", payload)
      {:noreply, socket}
    else
      {:error, :forbidden} -> {:reply, {:error, %{reason: "forbidden"}}, socket}
      {:error, :invalid_blob} -> {:reply, {:error, %{reason: "invalid_blob"}}, socket}
      {:error, _changeset} -> {:reply, {:error, %{reason: "invalid_update"}}, socket}
    end
  end

  def handle_in("doc_update", _payload, socket) do
    {:reply, {:error, %{reason: "blob is required"}}, socket}
  end

  defp fetch_stack_box(stack_box_id) do
    case StackBoxes.get_stack_box(stack_box_id) do
      nil -> {:error, :forbidden}
      stack_box -> {:ok, stack_box}
    end
  end

  defp ok_or({:ok, value}, _reason), do: {:ok, value}
  defp ok_or(:error, reason), do: {:error, reason}

  defp parse_id(id_str) do
    case Integer.parse(id_str) do
      {id, ""} -> {:ok, id}
      _ -> :error
    end
  end

  defp atomize_keys(map) do
    Map.new(map, fn {k, v} -> {String.to_existing_atom(k), v} end)
  end

  defp presence_json(presence) do
    %{
      stack_box_id: presence.stack_box_id,
      user_id: presence.user_id,
      cursor_x: presence.cursor_x,
      cursor_y: presence.cursor_y,
      selection: presence.selection,
      color: presence.color,
      last_seen_at: presence.last_seen_at
    }
  end

  defp doc_update_json(update) do
    %{
      id: update.id,
      stack_box_id: update.stack_box_id,
      blob: Base.encode64(update.blob),
      seq: update.seq,
      created_by: update.created_by,
      created_at: update.created_at
    }
  end
end
