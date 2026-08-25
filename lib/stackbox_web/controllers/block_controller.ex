defmodule StackboxWeb.BlockController do
  @moduledoc "Mirrors `backend/app/routers/blocks.py` (doc_blocks table)."

  use StackboxWeb, :controller

  alias Stackbox.Authorization
  alias Stackbox.StackBoxes

  action_fallback StackboxWeb.FallbackController

  @create_fields [
    "type",
    "language",
    "content",
    "sort_order",
    "pos_x",
    "pos_y",
    "width",
    "height"
  ]
  @update_fields @create_fields

  def index(conn, %{"stack_box_id" => stack_box_id}) do
    with {:ok, stack_box} <- fetch_stack_box(stack_box_id),
         {:ok, _role} <- require_role(stack_box.workspace_id, conn.assigns.current_user, :viewer) do
      blocks = StackBoxes.list_doc_blocks(stack_box.id)
      json(conn, Enum.map(blocks, &block_json/1))
    end
  end

  def create(conn, %{"stack_box_id" => stack_box_id} = params) do
    current_user = conn.assigns.current_user

    with {:ok, stack_box} <- fetch_stack_box(stack_box_id),
         {:ok, _role} <- require_role(stack_box.workspace_id, current_user, :editor),
         attrs = Map.take(params, @create_fields) |> Map.put("stack_box_id", stack_box.id),
         {:ok, block} <- StackBoxes.create_doc_block(attrs, current_user.id) do
      conn |> put_status(:created) |> json(block_json(block))
    end
  end

  def update(conn, %{"id" => id} = params) do
    current_user = conn.assigns.current_user

    with {:ok, block} <- fetch_block(id),
         {:ok, stack_box} <- fetch_stack_box(block.stack_box_id),
         {:ok, _role} <- require_role(stack_box.workspace_id, current_user, :editor),
         attrs = Map.take(params, @update_fields),
         {:ok, updated} <- StackBoxes.update_doc_block(block, attrs, current_user.id) do
      json(conn, block_json(updated))
    end
  end

  def delete(conn, %{"id" => id}) do
    with {:ok, block} <- fetch_block(id),
         {:ok, stack_box} <- fetch_stack_box(block.stack_box_id),
         {:ok, _role} <- require_role(stack_box.workspace_id, conn.assigns.current_user, :editor),
         {:ok, _} <- StackBoxes.delete_doc_block(block) do
      send_resp(conn, :no_content, "")
    end
  end

  @doc """
  Bulk reorder: `POST /stack-boxes/:stack_box_id/blocks/reorder` with body
  `{"blocks": [{"id" => block_id, "sort_order" => n}, ...]}`. There's no
  single-block-reorder equivalent in the FastAPI reference (`blocks.py` only
  has a per-block `/blocks/{block_id}/reorder`); this route's shape
  (`stack_box_id` in the path, no `:id`) is scaffolded for a batch reorder
  instead, so every referenced block is required to belong to the given
  stack box (checked in `StackBoxes.reorder_doc_blocks/3`) to prevent an
  attacker from reordering blocks in a stack box they don't have access to.
  """
  def reorder(conn, %{"stack_box_id" => stack_box_id, "blocks" => blocks}) when is_list(blocks) do
    current_user = conn.assigns.current_user

    with {:ok, stack_box} <- fetch_stack_box(stack_box_id),
         {:ok, _role} <- require_role(stack_box.workspace_id, current_user, :editor) do
      case StackBoxes.reorder_doc_blocks(stack_box.id, blocks, current_user.id) do
        {:ok, updated} -> json(conn, Enum.map(updated, &block_json/1))
        {:error, :not_found} -> {:error, :not_found, "Block not found"}
        {:error, %Ecto.Changeset{} = changeset} -> {:error, changeset}
      end
    end
  end

  def reorder(_conn, _params), do: {:error, :bad_request, "blocks is required"}

  defp fetch_stack_box(id) do
    with {:ok, int_id} <- parse_id(id) do
      case StackBoxes.get_stack_box(int_id) do
        nil -> {:error, :not_found, "StackBox not found"}
        stack_box -> {:ok, stack_box}
      end
    end
  end

  defp fetch_block(id) do
    with {:ok, int_id} <- parse_id(id) do
      case StackBoxes.get_doc_block(int_id) do
        nil -> {:error, :not_found, "Block not found"}
        block -> {:ok, block}
      end
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
      _ -> {:error, :not_found, "Not found"}
    end
  end

  defp block_json(block) do
    %{
      id: block.id,
      stack_box_id: block.stack_box_id,
      type: block.type,
      language: block.language,
      content: block.content,
      sort_order: block.sort_order,
      pos_x: block.pos_x,
      pos_y: block.pos_y,
      width: block.width,
      height: block.height,
      created_by: block.created_by,
      updated_by: block.updated_by,
      created_at: block.created_at,
      updated_at: block.updated_at
    }
  end
end
