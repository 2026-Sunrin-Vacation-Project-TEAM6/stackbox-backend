defmodule StackboxWeb.AuthControllerTest do
  use StackboxWeb.ConnCase, async: true

  alias Stackbox.Accounts

  describe "POST /auth/register" do
    test "creates a user and returns tokens", %{conn: conn} do
      conn =
        post(conn, "/auth/register", %{
          "email" => "new@example.com",
          "password" => "supersecret",
          "name" => "New User"
        })

      assert %{"access_token" => access, "refresh_token" => refresh, "token_type" => "bearer"} =
               json_response(conn, 201)

      assert is_binary(access)
      assert is_binary(refresh)
      assert Accounts.get_user_by_email("new@example.com")
    end

    test "rejects a password shorter than 8 characters", %{conn: conn} do
      conn =
        post(conn, "/auth/register", %{
          "email" => "short@example.com",
          "password" => "short",
          "name" => "Short"
        })

      assert json_response(conn, 422)
      refute Accounts.get_user_by_email("short@example.com")
    end

    test "rejects duplicate email with 409", %{conn: conn} do
      {:ok, _user} =
        Accounts.create_user(%{
          "email" => "dup@example.com",
          "password" => "supersecret",
          "name" => "A"
        })

      conn =
        post(conn, "/auth/register", %{
          "email" => "dup@example.com",
          "password" => "supersecret",
          "name" => "B"
        })

      assert json_response(conn, 409)
    end
  end

  describe "POST /auth/login" do
    setup do
      {:ok, user} =
        Accounts.create_user(%{
          "email" => "login@example.com",
          "password" => "supersecret",
          "name" => "L"
        })

      {:ok, user: user}
    end

    test "succeeds with correct credentials", %{conn: conn} do
      conn =
        post(conn, "/auth/login", %{"email" => "login@example.com", "password" => "supersecret"})

      assert %{"access_token" => _} = json_response(conn, 200)
    end

    test "rejects wrong password", %{conn: conn} do
      conn = post(conn, "/auth/login", %{"email" => "login@example.com", "password" => "wrong"})
      assert json_response(conn, 401)
    end

    test "rejects a deactivated user even with the correct password", %{conn: conn, user: user} do
      {:ok, _} = Stackbox.Repo.update(Ecto.Changeset.change(user, is_active: false))

      conn =
        post(conn, "/auth/login", %{"email" => "login@example.com", "password" => "supersecret"})

      assert json_response(conn, 401)
    end
  end

  describe "POST /auth/refresh and /auth/logout" do
    test "refresh issues a new token pair and invalidates the old refresh token", %{conn: conn} do
      {:ok, user} =
        Accounts.create_user(%{
          "email" => "refresh@example.com",
          "password" => "supersecret",
          "name" => "R"
        })

      login_conn =
        post(conn, "/auth/login", %{"email" => user.email, "password" => "supersecret"})

      %{"refresh_token" => refresh_token} = json_response(login_conn, 200)

      refresh_conn = post(conn, "/auth/refresh", %{"refresh_token" => refresh_token})
      assert %{"refresh_token" => new_refresh} = json_response(refresh_conn, 200)
      assert new_refresh != refresh_token

      # Old refresh token was single-use and is now gone.
      reused_conn = post(conn, "/auth/refresh", %{"refresh_token" => refresh_token})
      assert json_response(reused_conn, 401)
    end

    test "logout invalidates the refresh token", %{conn: conn} do
      {:ok, user} =
        Accounts.create_user(%{
          "email" => "logout@example.com",
          "password" => "supersecret",
          "name" => "O"
        })

      login_conn =
        post(conn, "/auth/login", %{"email" => user.email, "password" => "supersecret"})

      %{"refresh_token" => refresh_token} = json_response(login_conn, 200)

      logout_conn = post(conn, "/auth/logout", %{"refresh_token" => refresh_token})
      assert response(logout_conn, 204)

      reused_conn = post(conn, "/auth/refresh", %{"refresh_token" => refresh_token})
      assert json_response(reused_conn, 401)
    end
  end
end
