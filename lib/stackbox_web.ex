defmodule StackboxWeb do
  @moduledoc false

  def controller do
    quote do
      use Phoenix.Controller, formats: [:json]

      import Plug.Conn
      import StackboxWeb.Gettext

      unquote(verified_routes())
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: StackboxWeb.Endpoint,
        router: StackboxWeb.Router,
        statics: []
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
