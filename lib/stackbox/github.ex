defmodule Stackbox.Github do
  @moduledoc """
  Context for `github_accounts`, mirroring `backend/app/routers/github.py`.
  Encrypts/decrypts the stored OAuth token via `Stackbox.TokenCrypto`
  (Fernet-compatible with the existing Python-encrypted values), and makes
  the outbound OAuth/REST calls to GitHub via `Req` (mirroring the `httpx`
  calls in the Python reference).
  """

  import Ecto.Query, warn: false

  alias Stackbox.Repo
  alias Stackbox.Settings
  alias Stackbox.TokenCrypto
  alias Stackbox.Github.GithubAccount

  @github_authorize_url "https://github.com/login/oauth/authorize"
  @github_token_url "https://github.com/login/oauth/access_token"
  @github_api_url "https://api.github.com"

  # -- outbound HTTP (OAuth + REST API) --------------------------------------

  @doc "Builds the GitHub `authorize` redirect URL for `GET /github/oauth/login`."
  def oauth_authorize_url(state) do
    params = %{
      client_id: Settings.get(:github_client_id),
      redirect_uri: Settings.get(:github_oauth_redirect_uri),
      scope: "repo read:user",
      state: state
    }

    @github_authorize_url <> "?" <> URI.encode_query(params)
  end

  @doc "Exchanges an OAuth `code` for a GitHub access token."
  def exchange_code_for_token(code) do
    req()
    |> Req.post(
      url: @github_token_url,
      headers: [{"accept", "application/json"}],
      form: [
        client_id: Settings.get(:github_client_id),
        client_secret: Settings.get(:github_client_secret),
        code: code,
        redirect_uri: Settings.get(:github_oauth_redirect_uri)
      ]
    )
    |> case do
      {:ok, %Req.Response{status: 200, body: %{"access_token" => token}}} when is_binary(token) ->
        {:ok, token}

      {:ok, %Req.Response{status: status}} ->
        {:error, {:upstream_status, status}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  @doc "Fetches the authenticated GitHub user for `access_token`."
  def fetch_github_user(access_token) do
    req()
    |> Req.get(url: @github_api_url <> "/user", headers: auth_headers(access_token))
    |> handle_json_response()
  end

  @doc "Lists repositories for the GitHub user identified by `access_token`."
  def list_repos_for_token(access_token) do
    req()
    |> Req.get(
      url: @github_api_url <> "/user/repos",
      headers: auth_headers(access_token),
      params: [per_page: 100, sort: "updated"]
    )
    |> handle_json_response()
  end

  @doc "Lists the contents of `path` (may be `\"\"` for the repo root) in `owner/repo`."
  def list_contents_for_token(access_token, owner, repo, path) do
    req()
    |> Req.get(
      url: @github_api_url <> "/repos/#{owner}/#{repo}/contents/#{path}",
      headers: auth_headers(access_token)
    )
    |> handle_json_response()
  end

  @doc "Fetches the raw (non-JSON) content of a single file at `path` in `owner/repo`."
  def fetch_raw_content(access_token, owner, repo, path) do
    req()
    |> Req.get(
      url: @github_api_url <> "/repos/#{owner}/#{repo}/contents/#{path}",
      headers: [
        {"authorization", "Bearer #{access_token}"},
        {"accept", "application/vnd.github.raw+json"}
      ]
    )
    |> case do
      {:ok, %Req.Response{status: 200, body: body}} when is_binary(body) -> {:ok, body}
      {:ok, %Req.Response{status: 200, body: body}} -> {:ok, to_string(body)}
      {:ok, %Req.Response{status: status}} -> {:error, {:upstream_status, status}}
      {:error, reason} -> {:error, {:request_failed, reason}}
    end
  end

  defp handle_json_response({:ok, %Req.Response{status: status, body: body}})
       when status in 200..299,
       do: {:ok, body}

  defp handle_json_response({:ok, %Req.Response{status: status}}),
    do: {:error, {:upstream_status, status}}

  defp handle_json_response({:error, reason}), do: {:error, {:request_failed, reason}}

  defp auth_headers(access_token) do
    [{"authorization", "Bearer #{access_token}"}, {"accept", "application/vnd.github+json"}]
  end

  defp req, do: Req.new(Application.get_env(:stackbox, :github_req_options, []))

  # -- DB (github_accounts) --------------------------------------------------

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
