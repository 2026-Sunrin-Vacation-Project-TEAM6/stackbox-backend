defmodule StackboxWeb.AuthController do
  @moduledoc "Mirrors `backend/app/routers/auth.py`."

  use StackboxWeb, :controller

  alias Stackbox.Accounts
  alias Stackbox.Accounts.User
  alias Stackbox.Guardian
  alias Stackbox.Settings

  action_fallback StackboxWeb.FallbackController

  def register(conn, params) do
    case Accounts.get_user_by_email(params["email"]) do
      %User{} ->
        {:error, :conflict, "Email already registered"}

      nil ->
        with {:ok, user} <- Accounts.create_user(Map.take(params, ["email", "password", "name"])) do
          conn |> put_status(:created) |> json(issue_tokens(user))
        end
    end
  end

  def login(conn, %{"email" => email, "password" => password}) do
    case Accounts.authenticate_user(email, password) do
      {:ok, user} -> json(conn, issue_tokens(user))
      {:error, :invalid_credentials} -> {:error, :unauthorized, "Invalid email or password"}
    end
  end

  def login(_conn, _params), do: {:error, :unauthorized, "Invalid email or password"}

  def refresh(conn, %{"refresh_token" => refresh_token}) do
    with %{} = session <- Accounts.get_user_session_by_token_hash(hash_token(refresh_token)),
         false <- expired?(session),
         %User{is_active: true} = user <- Accounts.get_user(session.user_id) do
      Accounts.delete_user_session(session)
      json(conn, issue_tokens(user))
    else
      _ -> {:error, :unauthorized, "Invalid or expired refresh token"}
    end
  end

  def refresh(_conn, _params), do: {:error, :unauthorized, "Invalid or expired refresh token"}

  def logout(conn, %{"refresh_token" => refresh_token}) do
    case Accounts.get_user_session_by_token_hash(hash_token(refresh_token)) do
      nil -> :ok
      session -> Accounts.delete_user_session(session)
    end

    send_resp(conn, :no_content, "")
  end

  defp issue_tokens(user) do
    {:ok, access_token} = Guardian.create_access_token(user.id)
    refresh_token = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)

    {:ok, _session} =
      Accounts.create_user_session(%{
        user_id: user.id,
        token_hash: hash_token(refresh_token),
        expires_at: refresh_expires_at()
      })

    %{access_token: access_token, refresh_token: refresh_token, token_type: "bearer"}
  end

  defp refresh_expires_at do
    days = Settings.get(:refresh_token_expire_days)

    DateTime.utc_now()
    |> DateTime.add(days * 24 * 60 * 60, :second)
    |> DateTime.truncate(:second)
  end

  defp expired?(session), do: DateTime.compare(session.expires_at, DateTime.utc_now()) == :lt

  defp hash_token(token), do: :crypto.hash(:sha256, token) |> Base.encode16(case: :lower)
end
