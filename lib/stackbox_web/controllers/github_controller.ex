defmodule StackboxWeb.GithubController do
  @moduledoc "Mirrors `backend/app/routers/github.py`."

  use StackboxWeb, :controller

  alias Stackbox.Authorization
  alias Stackbox.Github
  alias Stackbox.Guardian
  alias Stackbox.Settings
  alias Stackbox.StackBoxes

  action_fallback StackboxWeb.FallbackController

  def oauth_login(conn, _params) do
    current_user = conn.assigns.current_user

    with {:ok, state} <- Guardian.create_oauth_state_token(current_user.id) do
      redirect(conn, external: Github.oauth_authorize_url(state))
    end
  end

  def oauth_callback(conn, %{"code" => code, "state" => state}) do
    with {:ok, user_id} <- decode_state(state),
         {:ok, access_token} <- exchange_code(code),
         {:ok, github_user} <- fetch_user(access_token),
         github_user_id = to_string(github_user["id"]),
         github_login = github_user["login"],
         {:ok, _account} <- connect(user_id, github_user_id, github_login, access_token) do
      redirect(conn, external: "#{Settings.get(:frontend_base_url)}/github?connected=1")
    end
  end

  def oauth_callback(_conn, _params), do: {:error, :bad_request, "code and state are required"}

  def get_account(conn, _params) do
    with {:ok, account} <- fetch_account(conn.assigns.current_user.id) do
      json(conn, account_json(account))
    end
  end

  def list_repos(conn, _params) do
    with {:ok, account} <- fetch_account(conn.assigns.current_user.id),
         {:ok, token} <- decrypt(account),
         {:ok, repos} <- Github.list_repos_for_token(token) do
      json(conn, Enum.map(repos, &repo_json/1))
    else
      {:error, reason} -> upstream_error(reason)
      other -> other
    end
  end

  @doc """
  `GET /github/contents?owner=..&repo=..&path=..`. The route (from
  `router.ex`) has no `:owner`/`:repo` path segments (unlike
  `backend/app/routers/github.py`'s `/repos/{owner}/{repo}/contents`), so
  those are accepted as query params instead.
  """
  def list_contents(conn, %{"owner" => owner, "repo" => repo} = params) do
    path = Map.get(params, "path", "")

    with {:ok, account} <- fetch_account(conn.assigns.current_user.id),
         {:ok, token} <- decrypt(account),
         {:ok, items} <- Github.list_contents_for_token(token, owner, repo, path) do
      items = if is_list(items), do: items, else: [items]
      json(conn, Enum.map(items, &content_json/1))
    else
      {:error, reason} -> upstream_error(reason)
      other -> other
    end
  end

  def list_contents(_conn, _params), do: {:error, :bad_request, "owner and repo are required"}

  def import_files(conn, %{"owner" => owner, "repo" => repo, "paths" => paths} = params)
      when is_list(paths) do
    current_user = conn.assigns.current_user

    with {:ok, stack_box_id} <- parse_id(params["stack_box_id"]),
         {:ok, stack_box} <- fetch_stack_box(stack_box_id),
         {:ok, _role} <- require_role(stack_box.workspace_id, current_user, :editor),
         {:ok, account} <- fetch_account(current_user.id),
         {:ok, token} <- decrypt(account),
         {:ok, block_ids} <- import_paths(token, owner, repo, paths, stack_box, current_user) do
      conn
      |> put_status(:created)
      |> json(%{imported: length(block_ids), block_ids: block_ids})
    else
      {:error, reason} when is_tuple(reason) -> upstream_error(reason)
      other -> other
    end
  end

  def import_files(_conn, _params),
    do: {:error, :bad_request, "owner, repo, paths, and stack_box_id are required"}

  defp import_paths(token, owner, repo, paths, stack_box, current_user) do
    max_sort = length(StackBoxes.list_doc_blocks(stack_box.id))

    paths
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {path, offset}, {:ok, acc} ->
      case Github.fetch_raw_content(token, owner, repo, path) do
        {:ok, content} ->
          attrs = %{
            "stack_box_id" => stack_box.id,
            "type" => "code",
            "language" => infer_language(path),
            "content" => content,
            "sort_order" => max_sort + offset
          }

          case StackBoxes.create_doc_block(attrs, current_user.id) do
            {:ok, block} -> {:cont, {:ok, acc ++ [block.id]}}
            {:error, changeset} -> {:halt, {:error, changeset}}
          end

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
  end

  @language_by_extension %{
    "py" => "python",
    "js" => "javascript",
    "ts" => "typescript",
    "tsx" => "typescript",
    "jsx" => "javascript",
    "rs" => "rust",
    "go" => "go",
    "rb" => "ruby",
    "java" => "java",
    "c" => "c",
    "cpp" => "cpp",
    "sh" => "bash",
    "md" => "markdown",
    "json" => "json",
    "yml" => "yaml",
    "yaml" => "yaml"
  }

  defp infer_language(path) do
    case String.split(path, ".") do
      [_single] -> nil
      parts -> Map.get(@language_by_extension, parts |> List.last() |> String.downcase())
    end
  end

  defp decode_state(state) do
    case Guardian.decode_oauth_state_token(state) do
      {:ok, user_id} -> {:ok, user_id}
      {:error, _reason} -> {:error, :bad_request, "invalid state"}
    end
  end

  defp exchange_code(code) do
    case Github.exchange_code_for_token(code) do
      {:ok, token} -> {:ok, token}
      {:error, _reason} -> {:error, :bad_gateway, "GitHub token exchange failed"}
    end
  end

  defp fetch_user(access_token) do
    case Github.fetch_github_user(access_token) do
      {:ok, %{"id" => _} = user} -> {:ok, user}
      {:ok, _other} -> {:error, :bad_gateway, "Failed to fetch GitHub user"}
      {:error, _reason} -> {:error, :bad_gateway, "Failed to fetch GitHub user"}
    end
  end

  defp connect(user_id, github_user_id, github_login, access_token) do
    case Github.connect_github_account(user_id, github_user_id, github_login, access_token) do
      {:ok, account} ->
        {:ok, account}

      {:error, %Ecto.Changeset{} = changeset} ->
        if Keyword.has_key?(changeset.errors, :github_user_id) do
          {:error, :conflict, "This GitHub account is already linked to another StackBox user"}
        else
          {:error, changeset}
        end
    end
  end

  defp fetch_account(user_id) do
    case Github.get_github_account_by_user(user_id) do
      nil -> {:error, :not_found, "GitHub account not connected"}
      account -> {:ok, account}
    end
  end

  defp decrypt(account) do
    case Github.decrypt_access_token(account) do
      {:ok, token} ->
        {:ok, token}

      {:error, _reason} ->
        {:error, :service_unavailable, "Stored GitHub token could not be decrypted"}
    end
  end

  defp upstream_error({:upstream_status, status}) when status in [401, 403],
    do: {:error, :bad_gateway, "GitHub rejected the request (status #{status})"}

  defp upstream_error({:upstream_status, status}),
    do: {:error, :bad_gateway, "GitHub API request failed (status #{status})"}

  defp upstream_error({:request_failed, _reason}),
    do: {:error, :bad_gateway, "GitHub API is unavailable"}

  defp fetch_stack_box(id) do
    case StackBoxes.get_stack_box(id) do
      nil -> {:error, :not_found, "StackBox not found"}
      stack_box -> {:ok, stack_box}
    end
  end

  defp require_role(workspace_id, user, minimum) do
    case Authorization.require_workspace_role(workspace_id, user, minimum) do
      {:ok, role} -> {:ok, role}
      {:error, :forbidden} -> {:error, :forbidden, "Insufficient workspace permissions"}
    end
  end

  defp parse_id(id) when is_integer(id), do: {:ok, id}

  defp parse_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {int_id, ""} -> {:ok, int_id}
      _ -> {:error, :not_found, "StackBox not found"}
    end
  end

  defp parse_id(_), do: {:error, :not_found, "StackBox not found"}

  defp account_json(account) do
    %{
      id: account.id,
      user_id: account.user_id,
      github_user_id: account.github_user_id,
      github_login: account.github_login,
      connected_at: account.connected_at
    }
  end

  defp repo_json(repo) do
    %{
      owner: repo["owner"]["login"],
      name: repo["name"],
      full_name: repo["full_name"],
      private: repo["private"],
      default_branch: repo["default_branch"]
    }
  end

  defp content_json(item) do
    %{
      path: item["path"],
      name: item["name"],
      type: item["type"],
      download_url: item["download_url"]
    }
  end
end
