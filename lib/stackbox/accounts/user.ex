defmodule Stackbox.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :email, :string
    field :password_hash, :string
    field :name, :string
    field :avatar_url, :string
    field :is_active, :boolean, default: true

    field :created_at, :utc_datetime, read_after_writes: true
    field :updated_at, :utc_datetime, read_after_writes: true
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :password_hash, :name, :avatar_url, :is_active])
    |> validate_required([:email, :name])
    |> validate_length(:email, max: 255)
    |> validate_length(:name, max: 100)
    |> unique_constraint(:email)
  end

  @doc false
  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :name, :avatar_url])
    |> validate_required([:email, :name])
    |> validate_length(:email, max: 255)
    |> validate_length(:name, max: 100)
    |> unique_constraint(:email)
    |> put_password_hash(attrs)
  end

  defp put_password_hash(changeset, %{"password" => password}) when is_binary(password) do
    put_change(changeset, :password_hash, Stackbox.Guardian.hash_password(password))
  end

  defp put_password_hash(changeset, %{password: password}) when is_binary(password) do
    put_change(changeset, :password_hash, Stackbox.Guardian.hash_password(password))
  end

  defp put_password_hash(changeset, _attrs), do: changeset
end
