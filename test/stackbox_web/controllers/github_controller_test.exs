defmodule StackboxWeb.GithubControllerTest do
  use StackboxWeb.ConnCase, async: true

  alias Stackbox.Accounts

  defp create_user(email) do
    {:ok, user} =
      Accounts.create_user(%{"email" => email, "password" => "supersecret", "name" => email})

    user
  end

  describe "GET /github/oauth/callback" do
    test "is reachable without an Authorization header (GitHub redirects the bare browser here)",
         %{conn: conn} do
      # No `authed_conn/1` here: this route is hit by a plain browser
      # navigation from GitHub's redirect, which never carries our API's
      # bearer token. If it were behind the `:auth` pipeline, AuthPlug would
      # 401 before the controller ever ran. Since we send a garbage `state`,
      # the controller itself rejects it with 400 - proving the request
      # reached `GithubController.oauth_callback/2` rather than being halted
      # by AuthPlug.
      conn = get(conn, "/github/oauth/callback", %{"code" => "somecode", "state" => "garbage"})

      assert json_response(conn, 400)
    end

    test "missing code/state params still reaches the controller (400, not 401)", %{conn: conn} do
      conn = get(conn, "/github/oauth/callback", %{})

      assert json_response(conn, 400)
    end
  end

  describe "GET /github/oauth/login" do
    test "requires authentication", %{conn: conn} do
      conn = get(conn, "/github/oauth/login")

      assert json_response(conn, 401)
    end
  end

  describe "GET /github/account" do
    test "requires authentication", %{conn: conn} do
      conn = get(conn, "/github/account")

      assert json_response(conn, 401)
    end

    test "returns 404 when no GitHub account is connected", %{conn: _conn} do
      user = create_user("nogithub@example.com")

      conn = authed_conn(user) |> get("/github/account")

      assert json_response(conn, 404)
    end
  end
end
