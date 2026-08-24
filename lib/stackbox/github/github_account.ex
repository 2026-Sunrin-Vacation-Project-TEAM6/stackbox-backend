defmodule Stackbox.Github.GithubAccount do
  use Ecto.Schema
  import Ecto.Changeset

  schema "github_accounts" do
    belongs_to :user, Stackbox.Accounts.User

    field :github_user_id, :string
    field :github_login, :string
    field :access_token_encrypted, :string

    field :connected_at, :utc_datetime, read_after_writes: true
  end

  @doc false
  def changeset(github_account, attrs) do
    github_account
    |> cast(attrs, [:user_id, :github_user_id, :github_login, :access_token_encrypted])
    |> validate_required([:user_id, :github_user_id, :github_login, :access_token_encrypted])
    |> validate_length(:github_user_id, max: 64)
    |> validate_length(:github_login, max: 255)
    |> unique_constraint(:user_id)
    |> unique_constraint(:github_user_id)
    |> foreign_key_constraint(:user_id)
  end
end
