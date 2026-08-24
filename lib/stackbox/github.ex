defmodule Stackbox.Github do
  @moduledoc """
  Context for `github_accounts`, mirroring `backend/app/routers/github.py`.
  Encrypts/decrypts the stored OAuth token via `Stackbox.TokenCrypto`
  (Fernet-compatible with the existing Python-encrypted values).
  """

  import Ecto.Query, warn: false

  alias Stackbox.Repo
  alias Stackbox.TokenCrypto
  alias Stackbox.Github.GithubAccount

  def get_github_account(id), do: Repo.get(GithubAccount, id)

  def get_github_account_by_user(user_id), do: Repo.get_by(GithubAccount, user_id: user_id)

  def get_github_account_by_github_user_id(github_user_id) do
    Repo.get_by(GithubAccount, github_user_id: github_user_id)
  end

  def connect_github_account(user_id, github_user_id, github_login, access_token) do
    attrs = %{
      user_id: user_id,
      github_user_id: github_user_id,
      github_login: github_login,
      access_token_encrypted: TokenCrypto.encrypt_token(access_token)
    }

    case get_github_account_by_user(user_id) do
      nil ->
        %GithubAccount{}
        |> GithubAccount.changeset(attrs)
        |> Repo.insert()

      %GithubAccount{} = account ->
        account
        |> GithubAccount.changeset(attrs)
        |> Repo.update()
    end
  end

  def disconnect_github_account(%GithubAccount{} = account), do: Repo.delete(account)

  def decrypt_access_token(%GithubAccount{access_token_encrypted: encrypted}) do
    TokenCrypto.decrypt_token(encrypted)
  end
end
