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

  def create_stack_box(attrs) do
    %StackBox{}
    |> StackBox.changeset(attrs)
    |> Repo.insert()
  end

  def update_stack_box(%StackBox{} = stack_box, attrs) do
    stack_box
    |> StackBox.changeset(attrs)
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

  def create_doc_block(attrs) do
    %DocBlock{}
    |> DocBlock.changeset(attrs)
    |> Repo.insert()
  end

  def update_doc_block(%DocBlock{} = block, attrs) do
    block
    |> DocBlock.changeset(attrs)
    |> Repo.update()
  end

  def delete_doc_block(%DocBlock{} = block), do: Repo.delete(block)

  # -- code_runs ------------------------------------------------------------

  def get_code_run(id), do: Repo.get(CodeRun, id)

  def list_code_runs(block_id) do
    from(r in CodeRun, where: r.block_id == ^block_id, order_by: [desc: r.id])
    |> Repo.all()
  end

  def create_code_run(attrs) do
    %CodeRun{}
    |> CodeRun.changeset(attrs)
    |> Repo.insert()
  end

  # -- doc_snapshots --------------------------------------------------------

  def get_doc_snapshot(stack_box_id), do: Repo.get(DocSnapshot, stack_box_id)

  def upsert_doc_snapshot(stack_box_id, attrs) do
    case get_doc_snapshot(stack_box_id) do
      nil ->
        %DocSnapshot{}
        |> DocSnapshot.changeset(Map.put(attrs, :stack_box_id, stack_box_id))
        |> Repo.insert()

      %DocSnapshot{} = snapshot ->
        snapshot
        |> DocSnapshot.changeset(attrs)
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

  def create_doc_update(attrs) do
    %DocUpdate{}
    |> DocUpdate.changeset(attrs)
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
        |> CanvasPresence.changeset(attrs)
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
