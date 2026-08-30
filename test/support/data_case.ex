defmodule Stackbox.DataCase do
  @moduledoc """
  Sets up an isolated Ecto sandbox connection for tests that touch the
  database directly (context tests, changeset tests).
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias Stackbox.Repo
      import Ecto
      import Ecto.Query
      import Stackbox.DataCase
    end
  end

  setup tags do
    Stackbox.DataCase.setup_sandbox(tags)
    :ok
  end

  def setup_sandbox(tags) do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Stackbox.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
  end
end
