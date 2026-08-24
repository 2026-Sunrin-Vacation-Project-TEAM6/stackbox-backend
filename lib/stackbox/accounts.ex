defmodule Stackbox.Accounts do
  @moduledoc """
  Context for `users` and `user_sessions`, mirroring `backend/app/routers/auth.py`
  and `backend/app/routers/users.py`.
  """

  import Ecto.Query, warn: false

  alias Stackbox.Repo
  alias Stackbox.Accounts.{User, UserSession}

  def get_user(id) when is_integer(id), do: Repo.get(User, id)

  def get_user(id) when is_binary(id) do
    case Integer.parse(id) do
      {int_id, ""} -> Repo.get(User, int_id)
      _ -> nil
    end
  end

  def get_user(_id), do: nil

  def get_user!(id), do: Repo.get!(User, id)

  def get_user_by_email(email), do: Repo.get_by(User, email: email)

  def create_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  def authenticate_user(email, password) do
    with %User{} = user <- get_user_by_email(email),
         true <- is_binary(user.password_hash),
         true <- Stackbox.Guardian.verify_password(password, user.password_hash) do
      {:ok, user}
    else
      _ -> {:error, :invalid_credentials}
    end
  end

  def create_user_session(attrs) do
    %UserSession{}
    |> UserSession.changeset(attrs)
    |> Repo.insert()
  end

  def get_user_session_by_token_hash(token_hash) do
    Repo.get_by(UserSession, token_hash: token_hash)
  end

  def delete_user_session(%UserSession{} = session), do: Repo.delete(session)

  def delete_expired_user_sessions do
    now = DateTime.utc_now()

    from(s in UserSession, where: s.expires_at < ^now)
    |> Repo.delete_all()
  end
end
