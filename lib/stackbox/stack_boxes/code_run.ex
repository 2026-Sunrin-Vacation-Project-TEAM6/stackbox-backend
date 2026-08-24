defmodule Stackbox.StackBoxes.CodeRun do
  use Ecto.Schema
  import Ecto.Changeset

  schema "code_runs" do
    belongs_to :block, Stackbox.StackBoxes.DocBlock, foreign_key: :block_id

    field :language, :string
    field :stdout, :string, default: ""
    field :stderr, :string, default: ""
    field :exit_code, :integer, default: 0
    field :duration_ms, :integer, default: 0

    field :executed_by, :id
    belongs_to :executed_by_user, Stackbox.Accounts.User, foreign_key: :executed_by, define_field: false

    field :created_at, :utc_datetime, read_after_writes: true
  end

  @doc false
  def changeset(code_run, attrs) do
    code_run
    |> cast(attrs, [:block_id, :language, :stdout, :stderr, :exit_code, :duration_ms, :executed_by])
    |> validate_required([:block_id, :language])
    |> validate_length(:language, max: 32)
    |> foreign_key_constraint(:block_id)
    |> foreign_key_constraint(:executed_by)
  end
end
