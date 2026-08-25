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
  Creation changeset for the initial snapshot upsert. `created_by`/
  `updated_by` are stamped server-side, mirroring
  `backend/app/routers/stack_boxes.py`'s `upsert_snapshot`.
  """
  def create_changeset(doc_snapshot, attrs, user_id) do
    doc_snapshot
    |> cast(attrs, [:stack_box_id, :blob, :state, :size])
    |> validate_required([:stack_box_id, :blob])
    |> validate_number(:size, greater_than_or_equal_to: 0)
    |> put_change(:version, 0)
    |> put_change(:created_by, user_id)
    |> put_change(:updated_by, user_id)
    |> foreign_key_constraint(:stack_box_id)
  end

  @doc """
  Update changeset for subsequent snapshot upserts. Increments `version` and
  stamps `updated_by` server-side.
  """
  def update_changeset(doc_snapshot, attrs, user_id) do
    doc_snapshot
    |> cast(attrs, [:blob, :state, :size])
    |> validate_required([:blob])
    |> validate_number(:size, greater_than_or_equal_to: 0)
    |> put_change(:version, doc_snapshot.version + 1)
    |> put_change(:updated_by, user_id)
  end
end
