defmodule Stackbox.Workspaces do
  @moduledoc """
  Context for `workspaces` and `workspace_members`, mirroring
  `backend/app/routers/workspaces.py` and `backend/app/access.py`.
  """

  import Ecto.Query, warn: false

  alias Stackbox.Repo
  alias Stackbox.Workspaces.{Workspace, WorkspaceMember}

  def get_workspace(id), do: Repo.get(Workspace, id)

  def get_workspace!(id), do: Repo.get!(Workspace, id)

  def get_workspace_by_slug(slug), do: Repo.get_by(Workspace, slug: slug)

  def list_workspaces_for_user(user_id) do
    from(w in Workspace,
      left_join: m in WorkspaceMember,
      on: m.workspace_id == w.id and m.user_id == ^user_id,
      where: w.owner_id == ^user_id or m.user_id == ^user_id,
      distinct: true
    )
    |> Repo.all()
  end

  def create_workspace(attrs) do
    %Workspace{}
    |> Workspace.changeset(attrs)
    |> Repo.insert()
  end

  def update_workspace(%Workspace{} = workspace, attrs) do
    workspace
    |> Workspace.changeset(attrs)
    |> Repo.update()
  end

  def delete_workspace(%Workspace{} = workspace), do: Repo.delete(workspace)

  def get_workspace_member(workspace_id, user_id) do
    Repo.get_by(WorkspaceMember, workspace_id: workspace_id, user_id: user_id)
  end

  def list_workspace_members(workspace_id) do
    from(m in WorkspaceMember, where: m.workspace_id == ^workspace_id)
    |> Repo.all()
  end

  def add_workspace_member(attrs) do
    %WorkspaceMember{}
    |> WorkspaceMember.changeset(attrs)
    |> Repo.insert()
  end

  def update_workspace_member(%WorkspaceMember{} = member, attrs) do
    member
    |> WorkspaceMember.changeset(attrs)
    |> Repo.update()
  end

  def remove_workspace_member(%WorkspaceMember{} = member), do: Repo.delete(member)

  @doc """
  Mirrors `access.py`'s `get_workspace_role`: the workspace owner implicitly
  holds the `:owner` role, otherwise falls back to the member row.
  """
  def get_workspace_role(%Workspace{owner_id: owner_id}, user_id) when owner_id == user_id,
    do: :owner

  def get_workspace_role(%Workspace{id: workspace_id}, user_id) do
    case get_workspace_member(workspace_id, user_id) do
      %WorkspaceMember{role: role} -> role
      nil -> nil
    end
  end
end
