defmodule StackboxWeb.StackBoxChannelTest do
  # `async: false`: channel joins/handlers run inside separate GenServer
  # processes (not the test process), so the Ecto sandbox needs the shared
  # (non-async) mode for those processes to use the same DB connection
  # without explicit `Ecto.Adapters.SQL.Sandbox.allow/3` calls.
  use StackboxWeb.ChannelCase, async: false

  alias Stackbox.Accounts
  alias Stackbox.StackBoxes
  alias Stackbox.Workspaces
  alias StackboxWeb.UserSocket

  setup do
    {:ok, owner} =
      Accounts.create_user(%{
        "email" => "owner@ch.example.com",
        "password" => "supersecret",
        "name" => "O"
      })

    {:ok, viewer} =
      Accounts.create_user(%{
        "email" => "viewer@ch.example.com",
        "password" => "supersecret",
        "name" => "V"
      })

    {:ok, outsider} =
      Accounts.create_user(%{
        "email" => "outsider@ch.example.com",
        "password" => "supersecret",
        "name" => "X"
      })

    {:ok, workspace} =
      Workspaces.create_workspace(%{"name" => "W", "slug" => "w-ch", "owner_id" => owner.id})

    {:ok, _member} =
      Workspaces.add_workspace_member(%{
        "workspace_id" => workspace.id,
        "user_id" => viewer.id,
        "role" => "viewer"
      })

    {:ok, stack_box} =
      StackBoxes.create_stack_box(
        %{"workspace_id" => workspace.id, "name" => "Doc", "type" => "page"},
        owner.id
      )

    %{
      owner: owner,
      viewer: viewer,
      outsider: outsider,
      workspace: workspace,
      stack_box: stack_box
    }
  end

  describe "socket connect/3" do
    test "accepts a valid JWT", %{owner: owner} do
      assert {:ok, socket} = connect(UserSocket, auth_params(owner))
      assert socket.assigns.current_user.id == owner.id
    end

    test "rejects a missing token" do
      assert :error = connect(UserSocket, %{})
    end

    test "rejects an invalid/garbage token" do
      assert :error = connect(UserSocket, %{"token" => "not-a-real-token"})
    end
  end

  describe "join/3" do
    test "a workspace viewer can join and receives a presence snapshot", %{
      viewer: viewer,
      stack_box: stack_box
    } do
      {:ok, _presence} =
        StackBoxes.upsert_canvas_presence(stack_box.id, viewer.id, %{
          cursor_x: 1.0,
          cursor_y: 2.0,
          color: "red"
        })

      {:ok, socket} = connect(UserSocket, auth_params(viewer))
      {:ok, _reply, _socket} = subscribe_and_join(socket, "stack_box:#{stack_box.id}", %{})

      assert_push "presence_snapshot", %{presences: presences}
      assert [%{user_id: user_id, color: "red"}] = presences
      assert user_id == viewer.id
    end

    test "a user with no workspace access is rejected", %{
      outsider: outsider,
      stack_box: stack_box
    } do
      {:ok, socket} = connect(UserSocket, auth_params(outsider))

      assert {:error, %{reason: "forbidden"}} =
               subscribe_and_join(socket, "stack_box:#{stack_box.id}", %{})
    end

    test "joining a nonexistent stack box is rejected", %{owner: owner} do
      {:ok, socket} = connect(UserSocket, auth_params(owner))

      assert {:error, %{reason: "not_found"}} =
               subscribe_and_join(socket, "stack_box:999999999", %{})
    end
  end

  describe "presence" do
    test "stamps user_id from the socket, never from the client payload, and excludes the sender",
         %{owner: owner, viewer: viewer, stack_box: stack_box} do
      {:ok, owner_socket} = connect(UserSocket, auth_params(owner))

      {:ok, _reply, _owner_socket} =
        subscribe_and_join(owner_socket, "stack_box:#{stack_box.id}", %{})

      assert_push "presence_snapshot", _

      {:ok, viewer_socket} = connect(UserSocket, auth_params(viewer))

      {:ok, _reply, viewer_socket} =
        subscribe_and_join(viewer_socket, "stack_box:#{stack_box.id}", %{})

      assert_push "presence_snapshot", _

      ref =
        push(viewer_socket, "presence", %{
          "cursor_x" => 10.0,
          "cursor_y" => 20.0,
          "color" => "blue",
          # A hostile/buggy client claiming to be the owner — must be ignored.
          "user_id" => owner.id
        })

      refute_reply ref, :error

      # The owner (a different socket) receives the broadcast, stamped with
      # the *actual* sender (viewer), not the spoofed value.
      assert_push "presence", %{user_id: user_id, cursor_x: 10.0, color: "blue"}
      assert user_id == viewer.id

      persisted = StackBoxes.list_canvas_presence(stack_box.id)
      assert Enum.find(persisted, &(&1.user_id == viewer.id)).color == "blue"

      # The sender itself does not get its own cursor echoed back.
      refute_push "presence", %{user_id: ^user_id}, 50
    end
  end

  describe "doc_update" do
    test "a viewer cannot append a doc update (requires editor+)", %{
      viewer: viewer,
      stack_box: stack_box
    } do
      {:ok, socket} = connect(UserSocket, auth_params(viewer))
      {:ok, _reply, socket} = subscribe_and_join(socket, "stack_box:#{stack_box.id}", %{})
      assert_push "presence_snapshot", _

      ref = push(socket, "doc_update", %{"blob" => Base.encode64("crdt-op")})
      assert_reply ref, :error, %{reason: "forbidden"}
    end

    test "an editor's update is persisted with a server-computed seq and broadcast", %{
      owner: owner,
      stack_box: stack_box
    } do
      {:ok, socket} = connect(UserSocket, auth_params(owner))
      {:ok, _reply, socket} = subscribe_and_join(socket, "stack_box:#{stack_box.id}", %{})
      assert_push "presence_snapshot", _

      blob = Base.encode64("crdt-op-1")
      ref = push(socket, "doc_update", %{"blob" => blob})
      refute_reply ref, :error

      assert_push "doc_update", %{blob: ^blob, seq: 1, created_by: created_by}
      assert created_by == owner.id

      [update] = StackBoxes.list_doc_updates(stack_box.id)
      assert update.seq == 1
      assert update.created_by == owner.id
    end
  end
end
