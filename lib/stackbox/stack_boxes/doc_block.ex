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
    belongs_to :created_by_user, Stackbox.Accounts.User, foreign_key: :created_by, define_field: false

    field :updated_by, :id
    belongs_to :updated_by_user, Stackbox.Accounts.User, foreign_key: :updated_by, define_field: false

    field :created_at, :utc_datetime, read_after_writes: true
    field :updated_at, :utc_datetime, read_after_writes: true
  end

  @doc false
  def changeset(doc_block, attrs) do
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
      :height,
      :created_by,
      :updated_by
    ])
    |> validate_required([:stack_box_id, :type])
    |> validate_length(:language, max: 32)
    |> foreign_key_constraint(:stack_box_id)
    |> foreign_key_constraint(:created_by)
    |> foreign_key_constraint(:updated_by)
  end
end
