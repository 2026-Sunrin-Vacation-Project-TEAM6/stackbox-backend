defmodule Stackbox.StackBoxes.DocUpdate do
  use Ecto.Schema
  import Ecto.Changeset

  schema "doc_updates" do
    belongs_to :stack_box, Stackbox.StackBoxes.StackBox

    field :blob, :binary
    field :seq, :integer

    field :created_by, :id

    belongs_to :created_by_user, Stackbox.Accounts.User,
      foreign_key: :created_by,
      define_field: false

    field :created_at, :utc_datetime, read_after_writes: true
  end

  @doc """
  Creation changeset. `created_by` is stamped server-side from the
  authenticated user.
  """
  def create_changeset(doc_update, attrs, creator_id) do
    doc_update
    |> cast(attrs, [:stack_box_id, :blob, :seq])
    |> validate_required([:stack_box_id, :blob, :seq])
    |> put_change(:created_by, creator_id)
    |> unique_constraint([:stack_box_id, :seq])
    |> foreign_key_constraint(:stack_box_id)
  end
end
