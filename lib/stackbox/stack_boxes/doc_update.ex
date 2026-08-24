defmodule Stackbox.StackBoxes.DocUpdate do
  use Ecto.Schema
  import Ecto.Changeset

  schema "doc_updates" do
    belongs_to :stack_box, Stackbox.StackBoxes.StackBox

    field :blob, :binary
    field :seq, :integer

    field :created_by, :id
    belongs_to :created_by_user, Stackbox.Accounts.User, foreign_key: :created_by, define_field: false

    field :created_at, :utc_datetime, read_after_writes: true
  end

  @doc false
  def changeset(doc_update, attrs) do
    doc_update
    |> cast(attrs, [:stack_box_id, :blob, :seq, :created_by])
    |> validate_required([:stack_box_id, :blob, :seq])
    |> unique_constraint([:stack_box_id, :seq])
    |> foreign_key_constraint(:stack_box_id)
    |> foreign_key_constraint(:created_by)
  end
end
