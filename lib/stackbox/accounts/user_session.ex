defmodule Stackbox.Accounts.UserSession do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_sessions" do
    field :token_hash, :string
    field :expires_at, :utc_datetime

    belongs_to :user, Stackbox.Accounts.User

    field :created_at, :utc_datetime, read_after_writes: true
  end

  @doc false
  def changeset(user_session, attrs) do
    user_session
    |> cast(attrs, [:user_id, :token_hash, :expires_at])
    |> validate_required([:user_id, :token_hash, :expires_at])
    |> unique_constraint(:token_hash)
    |> foreign_key_constraint(:user_id)
  end
end
