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

    belongs_to :executed_by_user, Stackbox.Accounts.User,
      foreign_key: :executed_by,
      define_field: false

    field :created_at, :utc_datetime, read_after_writes: true
  end

  @doc """
  Creation changeset. `executed_by` is stamped server-side from the
  authenticated user, not accepted from client attrs.
  """
  def create_changeset(code_run, attrs, executor_id) do
    code_run
    |> cast(attrs, [:block_id, :language, :stdout, :stderr, :exit_code, :duration_ms])
    |> validate_required([:block_id, :language])
    |> validate_length(:language, max: 32)
    |> put_change(:executed_by, executor_id)
    |> foreign_key_constraint(:block_id)
  end
end
