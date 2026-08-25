defmodule StackboxWeb.ConnCase do
  @moduledoc """
  Sets up a `Plug.Conn` for controller tests, with a DB sandbox connection
  and a helper for building an authenticated request.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      import Plug.Conn
      import Phoenix.ConnTest
      import StackboxWeb.ConnCase

      @endpoint StackboxWeb.Endpoint
    end
  end

  setup tags do
    Stackbox.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc "Builds a conn authenticated as `user` via a real Guardian-issued bearer token."
  def authed_conn(user) do
    {:ok, token} = Stackbox.Guardian.create_access_token(user.id)

    Phoenix.ConnTest.build_conn()
    |> Plug.Conn.put_req_header("authorization", "Bearer " <> token)
    |> Plug.Conn.put_req_header("content-type", "application/json")
  end
end
