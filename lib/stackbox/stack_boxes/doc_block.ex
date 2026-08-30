defmodule Stackbox.StackBoxes.DocBlock do
  use Ecto.Schema
  import Ecto.Changeset

  schema "doc_blocks" do
    belongs_to :stack_box, Stackbox.StackBoxes.StackBox

    field :type, Ecto.Enum, values: [:markdown, :code], default: :markdown
    field :language, :string
    field :content, :string, default: ""
    field :sort_order, :integer, default: 0
    field :pos_x, :float
    field :pos_y, :float
    field :width, :float
    field :height, :float

    field :created_by, :id

    belongs_to :created_by_user, Stackbox.Accounts.User,
      foreign_key: :created_by,
      define_field: false

    field :updated_by, :id

    belongs_to :updated_by_user, Stackbox.Accounts.User,
      foreign_key: :updated_by,
      define_field: false

    field :created_at, :utc_datetime, read_after_writes: true
    field :updated_at, :utc_datetime, read_after_writes: true
  end

  @doc """
  Creation changeset. `created_by`/`updated_by` are stamped server-side,
  mirroring `backend/app/routers/blocks.py`'s `create_block`.
  """
  def create_changeset(doc_block, attrs, creator_id) do
    doc_block
    |> cast(attrs, [
      :stack_box_id,
      :type,
      :language,
      :content,
      :sort_order,
      :pos_x,
      :pos_y,
      :width,
      :height
    ])
    |> validate_required([:stack_box_id, :type])
    |> validate_length(:language, max: 32)
    |> put_change(:created_by, creator_id)
    |> put_change(:updated_by, creator_id)
    |> foreign_key_constraint(:stack_box_id)
  end

  @doc """
  Update changeset. Excludes `stack_box_id` and stamps `updated_by`
  server-side.
  """
  def update_changeset(doc_block, attrs, updater_id) do
    doc_block
    |> cast(attrs, [:type, :language, :content, :sort_order, :pos_x, :pos_y, :width, :height])
    |> validate_length(:language, max: 32)
    |> put_change(:updated_by, updater_id)
  end

  @doc "Changeset used only for the `/blocks/:id/reorder` action."
  def reorder_changeset(doc_block, sort_order, updater_id) do
    doc_block
    |> cast(%{sort_order: sort_order}, [:sort_order])
    |> validate_required([:sort_order])
    |> put_change(:updated_by, updater_id)
  end
end
