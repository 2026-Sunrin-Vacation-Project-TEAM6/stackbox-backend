defmodule Stackbox.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :email, :string
    field :password_hash, :string
    field :name, :string
    field :avatar_url, :string
    field :is_active, :boolean, default: true
    field :password, :string, virtual: true, redact: true

    field :created_at, :utc_datetime, read_after_writes: true
    field :updated_at, :utc_datetime, read_after_writes: true
  end

  @doc """
  Self-service update changeset, mirroring `backend/app/schemas/user.py`'s
  `UserUpdate` (no `password_hash`/`is_active` — those aren't client-settable
  via this path).
  """
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :name, :avatar_url])
    |> validate_required([:email, :name])
    |> validate_length(:email, max: 255)
    |> validate_length(:name, max: 100)
    |> unique_constraint(:email)
  end

  @doc """
  Registration changeset, mirroring `RegisterRequest` in
  `backend/app/schemas/auth.py` (email/name/password, password required with
  an 8-255 char length bound — previously unvalidated here, allowing an empty
  or missing password to silently register with no password_hash).
  """
  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :name, :avatar_url, :password])
    |> validate_required([:email, :name, :password])
    |> validate_length(:email, max: 255)
    |> validate_length(:name, max: 100)
    |> validate_length(:password, min: 8, max: 255)
    |> unique_constraint(:email)
    |> put_password_hash()
  end

  defp put_password_hash(changeset) do
    case get_change(changeset, :password) do
      nil -> changeset
      password -> put_change(changeset, :password_hash, Stackbox.Guardian.hash_password(password))
    end
  end
end
