defmodule Stackbox.Authorization do
  @moduledoc false

  alias Stackbox.Repo
  alias Stackbox.Workspaces.{Workspace, WorkspaceMember}

  @role_rank %{viewer: 0, editor: 1, admin: 2, owner: 3}

  def role_rank(role), do: Map.fetch!(@role_rank, role)

  def get_workspace_role(workspace_id, user_id) do
    case Repo.get(Workspace, workspace_id) do
      nil ->
        nil

      %Workspace{owner_id: ^user_id} ->
        :owner

      _workspace ->
        case Repo.get_by(WorkspaceMember, workspace_id: workspace_id, user_id: user_id) do
          nil -> nil
          member -> member.role
        end
    end
  end

  def require_workspace_role(workspace_id, user, minimum) do
    role = get_workspace_role(workspace_id, user.id)

    if role == nil or role_rank(role) < role_rank(minimum) do
      {:error, :forbidden}
    else
      {:ok, role}
    end
  end
end
