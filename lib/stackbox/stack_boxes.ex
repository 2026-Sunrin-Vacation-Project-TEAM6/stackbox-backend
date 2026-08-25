defmodule Stackbox.StackBoxes do
  @moduledoc """
  Context for `stack_boxes`, `doc_blocks`, `code_runs`, `doc_snapshots`,
  `doc_updates`, and `canvas_presence`, mirroring
  `backend/app/routers/stack_boxes.py`, `backend/app/routers/blocks.py`,
  and `backend/app/routers/code_exec.py`.
  """

  import Ecto.Query, warn: false

  alias Stackbox.Repo

  alias Stackbox.StackBoxes.{
    StackBox,
    DocBlock,
    CodeRun,
    DocSnapshot,
    DocUpdate,
    CanvasPresence
  }

  # -- stack_boxes ------------------------------------------------------

  def get_stack_box(id), do: Repo.get(StackBox, id)

  def get_stack_box!(id), do: Repo.get!(StackBox, id)

  def list_stack_boxes(workspace_id) do
    from(sb in StackBox, where: sb.workspace_id == ^workspace_id, order_by: sb.sort_order)
    |> Repo.all()
  end

  def list_child_stack_boxes(workspace_id, parent_id) do
    from(sb in StackBox,
      where: sb.workspace_id == ^workspace_id and sb.parent_id == ^parent_id,
      order_by: sb.sort_order
    )
    |> Repo.all()
  end

  def create_stack_box(attrs, creator_id) do
    %StackBox{}
    |> StackBox.create_changeset(attrs, creator_id)
    |> Repo.insert()
  end

  def update_stack_box(%StackBox{} = stack_box, attrs, updater_id) do
    stack_box
    |> StackBox.update_changeset(attrs, updater_id)
    |> Repo.update()
  end

  def delete_stack_box(%StackBox{} = stack_box), do: Repo.delete(stack_box)

  # -- doc_blocks ---------------------------------------------------------

  def get_doc_block(id), do: Repo.get(DocBlock, id)

  def get_doc_block!(id), do: Repo.get!(DocBlock, id)

  def list_doc_blocks(stack_box_id) do
    from(b in DocBlock, where: b.stack_box_id == ^stack_box_id, order_by: b.sort_order)
    |> Repo.all()
  end

  def create_doc_block(attrs, creator_id) do
    %DocBlock{}
    |> DocBlock.create_changeset(attrs, creator_id)
    |> Repo.insert()
  end

  def update_doc_block(%DocBlock{} = block, attrs, updater_id) do
    block
    |> DocBlock.update_changeset(attrs, updater_id)
    |> Repo.update()
  end

  def reorder_doc_block(%DocBlock{} = block, sort_order, updater_id) do
    block
    |> DocBlock.reorder_changeset(sort_order, updater_id)
    |> Repo.update()
  end

  @doc """
  Bulk-reorders blocks. Each entry in `orders` must be
  `%{"id" => block_id, "sort_order" => n}`; every referenced block is
  required to belong to `stack_box_id` (looked up with a scoped
  `Repo.get_by/2`) so a caller can't use this to touch blocks outside the
  stack box they were authorized against.
  """
  def reorder_doc_blocks(stack_box_id, orders, updater_id) do
    Repo.transaction(fn ->
      Enum.map(orders, fn %{"id" => id, "sort_order" => sort_order} ->
        case Repo.get_by(DocBlock, id: id, stack_box_id: stack_box_id) do
          nil ->
            Repo.rollback(:not_found)

          block ->
            case reorder_doc_block(block, sort_order, updater_id) do
              {:ok, updated} -> updated
              {:error, changeset} -> Repo.rollback(changeset)
            end
        end
      end)
    end)
  end

  def delete_doc_block(%DocBlock{} = block), do: Repo.delete(block)

  # -- code_runs ------------------------------------------------------------

  def get_code_run(id), do: Repo.get(CodeRun, id)

  def list_code_runs(block_id) do
    from(r in CodeRun, where: r.block_id == ^block_id, order_by: [desc: r.id])
    |> Repo.all()
  end

  def create_code_run(attrs, executor_id) do
    %CodeRun{}
    |> CodeRun.create_changeset(attrs, executor_id)
    |> Repo.insert()
  end

  # -- doc_snapshots --------------------------------------------------------

  def get_doc_snapshot(stack_box_id), do: Repo.get(DocSnapshot, stack_box_id)

  def upsert_doc_snapshot(stack_box_id, attrs, user_id) do
    case get_doc_snapshot(stack_box_id) do
      nil ->
        %DocSnapshot{}
        |> DocSnapshot.create_changeset(Map.put(attrs, :stack_box_id, stack_box_id), user_id)
        |> Repo.insert()

      %DocSnapshot{} = snapshot ->
        snapshot
        |> DocSnapshot.update_changeset(attrs, user_id)
        |> Repo.update()
    end
  end

  # -- doc_updates -----------------------------------------------------------

  def list_doc_updates(stack_box_id, since_seq \\ 0) do
    from(u in DocUpdate,
      where: u.stack_box_id == ^stack_box_id and u.seq > ^since_seq,
      order_by: u.seq
    )
    |> Repo.all()
  end

  def create_doc_update(attrs, creator_id) do
    %DocUpdate{}
    |> DocUpdate.create_changeset(attrs, creator_id)
    |> Repo.insert()
  end

  def max_doc_update_seq(stack_box_id) do
    from(u in DocUpdate, where: u.stack_box_id == ^stack_box_id, select: max(u.seq))
    |> Repo.one()
    |> case do
      nil -> 0
      seq -> seq
    end
  end

  # -- canvas_presence --------------------------------------------------------

  def list_canvas_presence(stack_box_id) do
    from(p in CanvasPresence, where: p.stack_box_id == ^stack_box_id)
    |> Repo.all()
  end

  def upsert_canvas_presence(stack_box_id, user_id, attrs) do
    case Repo.get_by(CanvasPresence, stack_box_id: stack_box_id, user_id: user_id) do
      nil ->
        %CanvasPresence{}
        |> CanvasPresence.changeset(
          attrs
          |> Map.put(:stack_box_id, stack_box_id)
          |> Map.put(:user_id, user_id)
        )
        |> Repo.insert()

      %CanvasPresence{} = presence ->
        presence
        |> CanvasPresence.changeset(
          Map.drop(attrs, [:stack_box_id, :user_id, "stack_box_id", "user_id"])
        )
        |> Repo.update()
    end
  end

  def delete_canvas_presence(stack_box_id, user_id) do
    case Repo.get_by(CanvasPresence, stack_box_id: stack_box_id, user_id: user_id) do
      nil -> {:ok, nil}
      %CanvasPresence{} = presence -> Repo.delete(presence)
    end
  end
end
