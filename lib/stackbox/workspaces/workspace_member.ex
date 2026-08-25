defmodule Stackbox.Workspaces.WorkspaceMember do
  use Ecto.Schema
  import Ecto.Changeset

  schema "workspace_members" do
    field :role, Ecto.Enum, values: [:viewer, :editor, :admin, :owner], default: :viewer

    belongs_to :workspace, Stackbox.Workspaces.Workspace
    belongs_to :user, Stackbox.Accounts.User
    field :invited_by, :id

    belongs_to :invited_by_user, Stackbox.Accounts.User,
      foreign_key: :invited_by,
      define_field: false

    field :joined_at, :utc_datetime, read_after_writes: true
  end

  @doc """
  Creation changeset for adding a member, mirroring
  `WorkspaceMemberCreate`/the `add_workspace_member` route in
  `backend/app/routers/workspaces.py`, which rejects `role: owner` (ownership
  is only ever implicit via `workspaces.owner_id`).
  """
  def create_changeset(workspace_member, attrs) do
    workspace_member
    |> cast(attrs, [:workspace_id, :user_id, :role, :invited_by])
    |> validate_required([:workspace_id, :user_id, :role])
    |> validate_exclusion(:role, [:owner], message: "cannot grant owner role via membership")
    |> unique_constraint([:workspace_id, :user_id])
    |> foreign_key_constraint(:workspace_id)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:invited_by)
  end

  @doc """
  Update changeset for changing a member's role. Only `role` is mutable
  (mirrors `WorkspaceMemberUpdate`), and `owner` is still rejected.
  """
  def update_changeset(workspace_member, attrs) do
    workspace_member
    |> cast(attrs, [:role])
    |> validate_required([:role])
    |> validate_exclusion(:role, [:owner], message: "cannot grant owner role via membership")
  end
end
