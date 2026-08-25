defmodule StackboxWeb.WorkspaceControllerTest do
  use StackboxWeb.ConnCase, async: true

  alias Stackbox.Accounts
  alias Stackbox.Workspaces

  defp create_user(email) do
    {:ok, user} =
      Accounts.create_user(%{"email" => email, "password" => "supersecret", "name" => email})

    user
  end

  setup do
    owner = create_user("owner@example.com")
    admin = create_user("admin@example.com")
    editor = create_user("editor@example.com")
    outsider = create_user("outsider@example.com")

    {:ok, workspace} =
      Workspaces.create_workspace(%{
        "name" => "Acme",
        "slug" => "acme",
        "owner_id" => owner.id
      })

    {:ok, _admin_member} =
      Workspaces.add_workspace_member(%{
        "workspace_id" => workspace.id,
        "user_id" => admin.id,
        "role" => "admin"
      })

    {:ok, _editor_member} =
      Workspaces.add_workspace_member(%{
        "workspace_id" => workspace.id,
        "user_id" => editor.id,
        "role" => "editor"
      })

    %{owner: owner, admin: admin, editor: editor, outsider: outsider, workspace: workspace}
  end

  describe "create" do
    test "owner_id is always the authenticated user, never the request body", %{conn: _conn} do
      user = create_user("attacker@example.com")
      victim = create_user("victim@example.com")

      conn =
        authed_conn(user)
        |> post("/workspaces", %{"name" => "Evil", "slug" => "evil", "owner_id" => victim.id})

      body = json_response(conn, 201)
      assert body["owner_id"] == user.id
    end
  end

  describe "update" do
    test "editor cannot update workspace settings", %{editor: editor, workspace: workspace} do
      conn = authed_conn(editor) |> patch("/workspaces/#{workspace.id}", %{"name" => "Nope"})
      assert json_response(conn, 403)
    end

    test "admin can update workspace settings", %{admin: admin, workspace: workspace} do
      conn = authed_conn(admin) |> patch("/workspaces/#{workspace.id}", %{"name" => "Renamed"})
      assert json_response(conn, 200)["name"] == "Renamed"
    end

    test "owner_id cannot be reassigned via update, even by an admin", %{
      admin: admin,
      workspace: workspace,
      editor: editor
    } do
      conn =
        authed_conn(admin) |> patch("/workspaces/#{workspace.id}", %{"owner_id" => editor.id})

      body = json_response(conn, 200)
      assert body["owner_id"] == workspace.owner_id
    end

    test "outsider gets 403, not a leaked 404 vs 403 distinction bypass", %{
      outsider: outsider,
      workspace: workspace
    } do
      conn = authed_conn(outsider) |> patch("/workspaces/#{workspace.id}", %{"name" => "X"})
      assert json_response(conn, 403)
    end
  end

  describe "delete" do
    test "admin cannot delete the workspace (owner-only)", %{admin: admin, workspace: workspace} do
      conn = authed_conn(admin) |> delete("/workspaces/#{workspace.id}")
      assert json_response(conn, 403)
    end

    test "owner can delete the workspace", %{owner: owner, workspace: workspace} do
      conn = authed_conn(owner) |> delete("/workspaces/#{workspace.id}")
      assert response(conn, 204)
    end
  end

  describe "members" do
    test "editor cannot add members", %{editor: editor, workspace: workspace, outsider: outsider} do
      conn =
        authed_conn(editor)
        |> post("/workspaces/#{workspace.id}/members", %{
          "user_id" => outsider.id,
          "role" => "viewer"
        })

      assert json_response(conn, 403)
    end

    test "admin cannot grant owner role via membership", %{
      admin: admin,
      workspace: workspace,
      outsider: outsider
    } do
      conn =
        authed_conn(admin)
        |> post("/workspaces/#{workspace.id}/members", %{
          "user_id" => outsider.id,
          "role" => "owner"
        })

      assert json_response(conn, 400)
    end

    test "admin cannot promote a member to owner via update either", %{
      admin: admin,
      workspace: workspace,
      editor: editor
    } do
      conn =
        authed_conn(admin)
        |> patch("/workspaces/#{workspace.id}/members/#{editor.id}", %{"role" => "owner"})

      assert json_response(conn, 400)
    end

    test "a member can remove themself without admin rights", %{
      editor: editor,
      workspace: workspace
    } do
      conn = authed_conn(editor) |> delete("/workspaces/#{workspace.id}/members/#{editor.id}")
      assert response(conn, 204)
    end

    test "an editor cannot remove another member", %{
      editor: editor,
      admin: admin,
      workspace: workspace
    } do
      conn = authed_conn(editor) |> delete("/workspaces/#{workspace.id}/members/#{admin.id}")
      assert json_response(conn, 403)
    end
  end
end
