defmodule Stackbox.StackBoxes.DocSnapshot do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:stack_box_id, :id, autogenerate: false}
  schema "doc_snapshots" do
    belongs_to :stack_box, Stackbox.StackBoxes.StackBox, define_field: false

    field :blob, :binary
    field :state, :binary
    field :size, :integer, default: 0
    field :version, :integer, default: 0

    field :created_by, :id
    belongs_to :created_by_user, Stackbox.Accounts.User, foreign_key: :created_by, define_field: false

    field :updated_by, :id
    belongs_to :updated_by_user, Stackbox.Accounts.User, foreign_key: :updated_by, define_field: false

    field :created_at, :utc_datetime, read_after_writes: true
    field :updated_at, :utc_datetime, read_after_writes: true
  end

  @doc false
  def changeset(doc_snapshot, attrs) do
    doc_snapshot
    |> cast(attrs, [:stack_box_id, :blob, :state, :size, :version, :created_by, :updated_by])
    |> validate_required([:stack_box_id, :blob])
    |> validate_number(:size, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:stack_box_id)
    |> foreign_key_constraint(:created_by)
    |> foreign_key_constraint(:updated_by)
  end
end
