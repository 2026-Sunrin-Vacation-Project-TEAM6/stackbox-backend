defmodule Stackbox.Workspaces.Workspace do
  use Ecto.Schema
  import Ecto.Changeset

  schema "workspaces" do
    field :name, :string
    field :slug, :string
    field :description, :string, default: ""
    field :icon, :string

    belongs_to :owner, Stackbox.Accounts.User

    field :created_at, :utc_datetime, read_after_writes: true
    field :updated_at, :utc_datetime, read_after_writes: true
  end

  @doc """
  Creation changeset. `owner_id` is only settable here (server sets it from
  the authenticated user), mirroring `WorkspaceCreate` in
  `backend/app/schemas/workspace.py`.
  """
  def create_changeset(workspace, attrs) do
    workspace
    |> cast(attrs, [:name, :slug, :description, :icon, :owner_id])
    |> validate_required([:name, :slug, :owner_id])
    |> validate_length(:name, max: 255)
    |> validate_length(:slug, max: 100)
    |> unique_constraint(:slug)
    |> foreign_key_constraint(:owner_id)
  end

  @doc """
  Update changeset. Excludes `owner_id` (mirrors `WorkspaceUpdate`, which has
  no ownership-transfer field) so ownership can't be reassigned through a
  general workspace update.
  """
  def update_changeset(workspace, attrs) do
    workspace
    |> cast(attrs, [:name, :slug, :description, :icon])
    |> validate_length(:name, max: 255)
    |> validate_length(:slug, max: 100)
    |> unique_constraint(:slug)
  end
end
