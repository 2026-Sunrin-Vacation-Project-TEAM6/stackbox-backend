defmodule StackboxWeb.UserControllerTest do
  use StackboxWeb.ConnCase, async: true

  alias Stackbox.Accounts

  defp create_user(email) do
    {:ok, user} =
      Accounts.create_user(%{"email" => email, "password" => "supersecret", "name" => email})

    user
  end

  describe "GET /users/:id" do
    test "a user can view their own profile", %{conn: _conn} do
      user = create_user("self@example.com")
      conn = authed_conn(user) |> get("/users/#{user.id}")
      assert json_response(conn, 200)["id"] == user.id
    end

    test "a user cannot view another user's profile", %{conn: _conn} do
      user = create_user("a@example.com")
      other = create_user("b@example.com")
      conn = authed_conn(user) |> get("/users/#{other.id}")
      assert json_response(conn, 403)
    end
  end

  describe "PATCH /users/:id" do
    test "cannot self-reactivate/deactivate via is_active in the request body", %{conn: _conn} do
      user = create_user("noflip@example.com")

      conn =
        authed_conn(user)
        |> patch("/users/#{user.id}", %{"is_active" => false, "name" => "New Name"})

      body = json_response(conn, 200)
      assert body["name"] == "New Name"
      assert body["is_active"] == true
      assert Accounts.get_user(user.id).is_active
    end

    test "cannot overwrite password_hash directly", %{conn: _conn} do
      user = create_user("nohash@example.com")
      original_hash = user.password_hash

      conn = authed_conn(user) |> patch("/users/#{user.id}", %{"password_hash" => "haxx"})

      assert json_response(conn, 200)
      assert Accounts.get_user(user.id).password_hash == original_hash
    end
  end
end
