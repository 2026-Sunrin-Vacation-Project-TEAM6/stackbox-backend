defmodule StackboxWeb.UserSocket do
  @moduledoc """
  Referenced by `StackboxWeb.Endpoint`'s `socket("/socket", ...)` mount, but
  never implemented — its absence crashed `StackboxWeb.Endpoint`'s
  supervisor on every application start (`UndefinedFunctionError:
  StackboxWeb.UserSocket.child_spec/1`), including under `mix test`.

  No channels exist yet (realtime/canvas presence isn't wired up in this
  phase), so every connection is explicitly rejected rather than silently
  accepting unauthenticated socket connections.
  """

  use Phoenix.Socket

  @impl true
  def connect(_params, _socket, _connect_info), do: :error

  @impl true
  def id(_socket), do: nil
end
