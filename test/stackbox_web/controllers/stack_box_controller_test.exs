defmodule StackboxWeb.StackBoxControllerTest do
  use StackboxWeb.ConnCase, async: true

  alias Stackbox.Accounts
  alias Stackbox.Workspaces

  setup do
    {:ok, owner} =
      Accounts.create_user(%{
        "email" => "owner@sb.example.com",
        "password" => "supersecret",
        "name" => "O"
      })

    {:ok, viewer} =
      Accounts.create_user(%{
        "email" => "viewer@sb.example.com",
        "password" => "supersecret",
        "name" => "V"
      })

    {:ok, workspace} =
      Workspaces.create_workspace(%{"name" => "W", "slug" => "w-sb", "owner_id" => owner.id})

    {:ok, _member} =
      Workspaces.add_workspace_member(%{
        "workspace_id" => workspace.id,
        "user_id" => viewer.id,
        "role" => "viewer"
      })

    %{owner: owner, viewer: viewer, workspace: workspace}
  end

  test "created_by/updated_by are stamped from the authenticated user, not the request body", %{
    owner: owner,
    viewer: viewer,
    workspace: workspace
  } do
    conn =
      authed_conn(owner)
      |> post("/stack-boxes", %{
        "workspace_id" => workspace.id,
        "name" => "Doc",
        "type" => "page",
        "created_by" => viewer.id
      })

    body = json_response(conn, 201)
    stack_box = Stackbox.StackBoxes.get_stack_box(body["id"])
    assert stack_box.created_by == owner.id
    assert stack_box.updated_by == owner.id
  end

  test "a viewer cannot create a stack box (requires editor+)", %{
    viewer: viewer,
    workspace: workspace
  } do
    conn =
      authed_conn(viewer)
      |> post("/stack-boxes", %{"workspace_id" => workspace.id, "name" => "Doc", "type" => "page"})

    assert json_response(conn, 403)
  end

  test "a viewer can read stack boxes in their workspace", %{
    owner: owner,
    viewer: viewer,
    workspace: workspace
  } do
    {:ok, stack_box} =
      Stackbox.StackBoxes.create_stack_box(
        %{"workspace_id" => workspace.id, "name" => "Doc", "type" => "page"},
        owner.id
      )

    conn = authed_conn(viewer) |> get("/stack-boxes/#{stack_box.id}")
    assert json_response(conn, 200)["id"] == stack_box.id
  end
end
