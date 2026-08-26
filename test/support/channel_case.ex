defmodule StackboxWeb.ChannelCase do
  @moduledoc """
  Sets up a DB sandbox connection and imports `Phoenix.ChannelTest` helpers
  for channel tests.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      import Phoenix.ChannelTest
      import StackboxWeb.ChannelCase

      @endpoint StackboxWeb.Endpoint
    end
  end

  setup tags do
    Stackbox.DataCase.setup_sandbox(tags)
    :ok
  end

  @doc "Builds a `UserSocket` connect params map authenticated as `user` via a real Guardian token."
  def auth_params(user) do
    {:ok, token} = Stackbox.Guardian.create_access_token(user.id)
    %{"token" => token}
  end
end
