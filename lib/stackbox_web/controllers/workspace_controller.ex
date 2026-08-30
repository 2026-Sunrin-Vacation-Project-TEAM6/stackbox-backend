defmodule StackboxWeb.WorkspaceController do
  @moduledoc "Mirrors `backend/app/routers/workspaces.py`."

  use StackboxWeb, :controller

  alias Stackbox.Authorization
  alias Stackbox.Workspaces
  alias Stackbox.Workspaces.{Workspace, WorkspaceMember}

  action_fallback StackboxWeb.FallbackController

  def create(conn, params) do
    attrs =
      params
      |> Map.take(["name", "slug", "description", "icon"])
      |> Map.put("owner_id", conn.assigns.current_user.id)

    with {:ok, workspace} <- Workspaces.create_workspace(attrs) do
      conn |> put_status(:created) |> json(workspace_json(workspace))
    end
  end

  def index(conn, _params) do
    workspaces = Workspaces.list_workspaces_for_user(conn.assigns.current_user.id)
    json(conn, Enum.map(workspaces, &workspace_json/1))
  end

  def show(conn, %{"id" => id}) do
    with {:ok, workspace} <- fetch_workspace(id),
         {:ok, _role} <- require_role(workspace, conn.assigns.current_user, :viewer) do
      json(conn, workspace_json(workspace))
    end
  end

  def update(conn, %{"id" => id} = params) do
    with {:ok, workspace} <- fetch_workspace(id),
         {:ok, _role} <- require_role(workspace, conn.assigns.current_user, :admin),
         attrs = Map.take(params, ["name", "slug", "description", "icon"]),
         {:ok, updated} <- Workspaces.update_workspace(workspace, attrs) do
      json(conn, workspace_json(updated))
    end
  end

  def delete(conn, %{"id" => id}) do
    with {:ok, workspace} <- fetch_workspace(id),
         {:ok, _role} <- require_role(workspace, conn.assigns.current_user, :owner),
         {:ok, _} <- Workspaces.delete_workspace(workspace) do
      send_resp(conn, :no_content, "")
    end
  end

  def add_member(conn, %{"id" => id} = params) do
    with {:ok, workspace} <- fetch_workspace(id),
         {:ok, _role} <- require_role(workspace, conn.assigns.current_user, :admin),
         :ok <- reject_owner_role(params["role"]),
         attrs = %{
           "workspace_id" => workspace.id,
           "user_id" => params["user_id"],
           "role" => params["role"] || "viewer",
           "invited_by" => conn.assigns.current_user.id
         },
         {:ok, member} <- Workspaces.add_workspace_member(attrs) do
      conn |> put_status(:created) |> json(member_json(member))
    end
  end

  def list_members(conn, %{"id" => id}) do
    with {:ok, workspace} <- fetch_workspace(id),
         {:ok, _role} <- require_role(workspace, conn.assigns.current_user, :viewer) do
      members = Workspaces.list_workspace_members(workspace.id)
      json(conn, Enum.map(members, &member_json/1))
    end
  end

  def update_member(conn, %{"id" => id, "user_id" => user_id} = params) do
    with {:ok, workspace} <- fetch_workspace(id),
         {:ok, member} <- fetch_member(workspace.id, user_id),
         {:ok, _role} <- require_role(workspace, conn.assigns.current_user, :admin),
         :ok <- reject_owner_role(params["role"]),
         {:ok, updated} <- Workspaces.update_workspace_member(member, Map.take(params, ["role"])) do
      json(conn, member_json(updated))
    end
  end

  def remove_member(conn, %{"id" => id, "user_id" => user_id}) do
    current_user = conn.assigns.current_user

    with {:ok, workspace} <- fetch_workspace(id),
         {:ok, member} <- fetch_member(workspace.id, user_id),
         :ok <- allow_self_or_admin(workspace, current_user, member),
         {:ok, _} <- Workspaces.remove_workspace_member(member) do
      send_resp(conn, :no_content, "")
    end
  end

  defp fetch_workspace(id) do
    case Integer.parse(id) do
      {int_id, ""} ->
        case Workspaces.get_workspace(int_id) do
          nil -> {:error, :not_found, "Workspace not found"}
          workspace -> {:ok, workspace}
        end

      _ ->
        {:error, :not_found, "Workspace not found"}
    end
  end

  defp fetch_member(workspace_id, user_id) do
    case Integer.parse(user_id) do
      {int_id, ""} ->
        case Workspaces.get_workspace_member(workspace_id, int_id) do
          nil -> {:error, :not_found, "Workspace member not found"}
          member -> {:ok, member}
        end

      _ ->
        {:error, :not_found, "Workspace member not found"}
    end
  end

  defp require_role(%Workspace{} = workspace, user, minimum) do
    case Authorization.require_workspace_role(workspace.id, user, minimum) do
      {:ok, role} -> {:ok, role}
      {:error, :forbidden} -> {:error, :forbidden, "Insufficient workspace permissions"}
    end
  end

  defp allow_self_or_admin(_workspace, current_user, %WorkspaceMember{user_id: user_id})
       when user_id == current_user.id do
    :ok
  end

  defp allow_self_or_admin(workspace, current_user, _member) do
    case require_role(workspace, current_user, :admin) do
      {:ok, _role} -> :ok
      error -> error
    end
  end

  defp reject_owner_role(role) when role in ["owner", :owner],
    do: {:error, :bad_request, "Cannot grant owner role via membership"}

  defp reject_owner_role(_role), do: :ok

  defp workspace_json(workspace) do
    %{
      id: workspace.id,
      name: workspace.name,
      slug: workspace.slug,
      description: workspace.description,
      icon: workspace.icon,
      owner_id: workspace.owner_id,
      created_at: workspace.created_at,
      updated_at: workspace.updated_at
    }
  end

  defp member_json(member) do
    %{
      id: member.id,
      workspace_id: member.workspace_id,
      user_id: member.user_id,
      role: member.role,
      invited_by: member.invited_by,
      joined_at: member.joined_at
    }
  end
end
