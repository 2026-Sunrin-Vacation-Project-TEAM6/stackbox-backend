defmodule StackboxWeb.UserController do
  @moduledoc "Mirrors `backend/app/routers/users.py`."

  use StackboxWeb, :controller

  alias Stackbox.Accounts

  action_fallback StackboxWeb.FallbackController

  def show(conn, %{"id" => id}) do
    with {:ok, user} <- require_self(conn, id) do
      json(conn, user_json(user))
    end
  end

  def update(conn, %{"id" => id} = params) do
    with {:ok, user} <- require_self(conn, id),
         {:ok, updated} <-
           Accounts.update_user(user, Map.take(params, ["email", "name", "avatar_url"])) do
      json(conn, user_json(updated))
    end
  end

  def delete(conn, %{"id" => id}) do
    with {:ok, user} <- require_self(conn, id),
         {:ok, _} <- Accounts.delete_user(user) do
      send_resp(conn, :no_content, "")
    end
  end

  defp require_self(conn, id) do
    current_user = conn.assigns.current_user

    case Integer.parse(id) do
      {int_id, ""} when int_id == current_user.id -> {:ok, current_user}
      {_int_id, ""} -> {:error, :forbidden, "Not authorized"}
      _ -> {:error, :not_found, "User not found"}
    end
  end

  defp user_json(user) do
    %{
      id: user.id,
      email: user.email,
      name: user.name,
      avatar_url: user.avatar_url,
      is_active: user.is_active,
      created_at: user.created_at,
      updated_at: user.updated_at
    }
  end
end
