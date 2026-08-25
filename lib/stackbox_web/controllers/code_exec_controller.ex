defmodule StackboxWeb.CodeExecController do
  @moduledoc """
  Placeholder for `backend/app/routers/code_exec.py`. No Elixir client for
  the external code-runner service has been ported yet, so these actions
  explicitly return 501 rather than fabricate an unverified integration.
  `Stackbox.StackBoxes.create_code_run/2` (backing context/schema) already
  exists for when this is implemented.
  """

  use StackboxWeb, :controller

  def run_block(conn, _params), do: not_implemented(conn)
  def list_runs(conn, _params), do: not_implemented(conn)

  defp not_implemented(conn) do
    conn |> put_status(:not_implemented) |> json(%{detail: "Not implemented yet"})
  end
end
