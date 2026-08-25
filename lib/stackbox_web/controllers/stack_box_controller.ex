defmodule StackboxWeb.StackBoxController do
  @moduledoc "Mirrors `backend/app/routers/stack_boxes.py`."

  use StackboxWeb, :controller

  alias Stackbox.Authorization
  alias Stackbox.StackBoxes
  alias Stackbox.StackBoxes.StackBox

  action_fallback StackboxWeb.FallbackController

  @create_fields [
    "workspace_id",
    "parent_id",
    "type",
    "name",
    "description",
    "icon",
    "cover_url",
    "sort_order"
  ]
  @update_fields ["parent_id", "type", "name", "description", "icon", "cover_url", "sort_order"]

  def create(conn, params) do
    current_user = conn.assigns.current_user

    with {:ok, workspace_id} <- parse_id(params["workspace_id"]),
         {:ok, _role} <- require_role(workspace_id, current_user, :editor),
         attrs = Map.take(params, @create_fields),
         {:ok, stack_box} <- StackBoxes.create_stack_box(attrs, current_user.id) do
      conn |> put_status(:created) |> json(stack_box_json(stack_box))
    end
  end

  def index(conn, params) do
    current_user = conn.assigns.current_user

    with {:ok, workspace_id} <- parse_id(params["workspace_id"]),
         {:ok, _role} <- require_role(workspace_id, current_user, :viewer) do
      stack_boxes =
        case params["parent_id"] do
          nil ->
            StackBoxes.list_stack_boxes(workspace_id)

          parent_id ->
            case parse_id(parent_id) do
              {:ok, int_id} -> StackBoxes.list_child_stack_boxes(workspace_id, int_id)
              {:error, _, _} -> []
            end
        end

      json(conn, Enum.map(stack_boxes, &stack_box_json/1))
    end
  end

  def show(conn, %{"id" => id}) do
    with {:ok, stack_box} <- fetch_stack_box(id),
         {:ok, _role} <- require_role(stack_box.workspace_id, conn.assigns.current_user, :viewer) do
      json(conn, stack_box_json(stack_box))
    end
  end

  def update(conn, %{"id" => id} = params) do
    current_user = conn.assigns.current_user

    with {:ok, stack_box} <- fetch_stack_box(id),
         {:ok, _role} <- require_role(stack_box.workspace_id, current_user, :editor),
         attrs = Map.take(params, @update_fields),
         {:ok, updated} <- StackBoxes.update_stack_box(stack_box, attrs, current_user.id) do
      json(conn, stack_box_json(updated))
    end
  end

  def delete(conn, %{"id" => id}) do
    with {:ok, stack_box} <- fetch_stack_box(id),
         {:ok, _role} <- require_role(stack_box.workspace_id, conn.assigns.current_user, :editor),
         {:ok, _} <- StackBoxes.delete_stack_box(stack_box) do
      send_resp(conn, :no_content, "")
    end
  end

  def get_snapshot(conn, %{"id" => id}) do
    with {:ok, stack_box} <- fetch_stack_box(id),
         {:ok, _role} <- require_role(stack_box.workspace_id, conn.assigns.current_user, :viewer) do
      case StackBoxes.get_doc_snapshot(stack_box.id) do
        nil -> {:error, :not_found, "Snapshot not found"}
        snapshot -> json(conn, snapshot_json(snapshot))
      end
    end
  end

  def upsert_snapshot(conn, %{"id" => id, "blob" => blob} = params) do
    current_user = conn.assigns.current_user

    with {:ok, stack_box} <- fetch_stack_box(id),
         {:ok, _role} <- require_role(stack_box.workspace_id, current_user, :editor),
         {:ok, blob_bin} <- decode_base64(blob),
         {:ok, state_bin} <- decode_base64(params["state"]),
         attrs = %{blob: blob_bin, state: state_bin, size: byte_size(blob_bin)},
         {:ok, snapshot} <- StackBoxes.upsert_doc_snapshot(stack_box.id, attrs, current_user.id) do
      json(conn, snapshot_json(snapshot))
    end
  end

  def upsert_snapshot(_conn, _params), do: {:error, :bad_request, "blob is required"}

  def list_doc_updates(conn, %{"id" => id} = params) do
    with {:ok, stack_box} <- fetch_stack_box(id),
         {:ok, _role} <- require_role(stack_box.workspace_id, conn.assigns.current_user, :viewer) do
      since_seq = parse_int(params["since_seq"], 0)
      updates = StackBoxes.list_doc_updates(stack_box.id, since_seq)
      json(conn, Enum.map(updates, &doc_update_json/1))
    end
  end

  def list_presence(conn, %{"id" => id}) do
    with {:ok, stack_box} <- fetch_stack_box(id),
         {:ok, _role} <- require_role(stack_box.workspace_id, conn.assigns.current_user, :viewer) do
      presence = StackBoxes.list_canvas_presence(stack_box.id)
      json(conn, Enum.map(presence, &presence_json/1))
    end
  end

  defp fetch_stack_box(id) do
    with {:ok, int_id} <- parse_id(id) do
      case StackBoxes.get_stack_box(int_id) do
        nil -> {:error, :not_found, "StackBox not found"}
        %StackBox{} = stack_box -> {:ok, stack_box}
      end
    else
      _ -> {:error, :not_found, "StackBox not found"}
    end
  end

  defp require_role(workspace_id, user, minimum) do
    case Authorization.require_workspace_role(workspace_id, user, minimum) do
      {:ok, role} -> {:ok, role}
      {:error, :forbidden} -> {:error, :forbidden, "Insufficient workspace permissions"}
    end
  end

  defp parse_id(id) when is_integer(id), do: {:ok, id}

  defp parse_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {int_id, ""} -> {:ok, int_id}
      _ -> {:error, :not_found, "StackBox not found"}
    end
  end

  defp parse_id(_), do: {:error, :not_found, "StackBox not found"}

  defp parse_int(nil, default), do: default

  defp parse_int(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> default
    end
  end

  defp decode_base64(nil), do: {:ok, nil}

  defp decode_base64(data) when is_binary(data) do
    case Base.decode64(data) do
      {:ok, decoded} -> {:ok, decoded}
      :error -> {:error, :bad_request, "Invalid base64 payload"}
    end
  end

  defp encode_base64(nil), do: nil
  defp encode_base64(data), do: Base.encode64(data)

  defp stack_box_json(stack_box) do
    %{
      id: stack_box.id,
      workspace_id: stack_box.workspace_id,
      parent_id: stack_box.parent_id,
      type: stack_box.type,
      name: stack_box.name,
      description: stack_box.description,
      icon: stack_box.icon,
      cover_url: stack_box.cover_url,
      sort_order: stack_box.sort_order,
      created_at: stack_box.created_at,
      updated_at: stack_box.updated_at
    }
  end

  defp snapshot_json(snapshot) do
    %{
      stack_box_id: snapshot.stack_box_id,
      blob: encode_base64(snapshot.blob),
      state: encode_base64(snapshot.state),
      size: snapshot.size,
      version: snapshot.version,
      created_by: snapshot.created_by,
      updated_by: snapshot.updated_by,
      created_at: snapshot.created_at,
      updated_at: snapshot.updated_at
    }
  end

  defp doc_update_json(update) do
    %{
      id: update.id,
      stack_box_id: update.stack_box_id,
      blob: encode_base64(update.blob),
      seq: update.seq,
      created_by: update.created_by,
      created_at: update.created_at
    }
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
end
