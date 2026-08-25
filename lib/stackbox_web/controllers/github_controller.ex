defmodule StackboxWeb.GithubController do
  @moduledoc """
  Placeholder for `backend/app/routers/github.py`. Unlike users/workspaces/
  stack_boxes/blocks/reactions, no Elixir GitHub OAuth client or context has
  been ported yet (no equivalent of `app/routers/github.py`'s httpx calls to
  GitHub's OAuth/REST API exists in this codebase). Rather than leave the
  router pointing at an undefined module (a hard compile/runtime error) or
  fabricate an unverified OAuth integration, these actions explicitly return
  501 until that work is scoped and implemented.
  """

  use StackboxWeb, :controller

  def oauth_login(conn, _params), do: not_implemented(conn)
  def oauth_callback(conn, _params), do: not_implemented(conn)
  def get_account(conn, _params), do: not_implemented(conn)
  def list_repos(conn, _params), do: not_implemented(conn)
  def list_contents(conn, _params), do: not_implemented(conn)
  def import_files(conn, _params), do: not_implemented(conn)

  defp not_implemented(conn) do
    conn |> put_status(:not_implemented) |> json(%{detail: "Not implemented yet"})
  end
end
