defmodule StackboxWeb.UserSocket do
  @moduledoc """
  Authenticates realtime (WebSocket) connections the same way
  `StackboxWeb.Plugs.AuthPlug` authenticates HTTP requests: a Guardian JWT
  is verified and the resolved, active user is stored in `socket.assigns`.

  Unlike an HTTP `Authorization` header, a browser `WebSocket` connection
  can't set custom headers, so the token is passed as a connect param
  instead (`new Socket("/socket", {params: {token}})` on the client), the
  same convention `web_worker`'s `/ws/{stack_box_id}?token=...` uses (see
  `web_worker/src/main.rs`'s `WsParams`).

  Connections without a valid token for an active user are rejected
  outright (`:error`), same as before Phase 1's realtime work started —
  the only change is that a *valid* token is now accepted instead of
  everything being rejected.
  """

  use Phoenix.Socket

  alias Stackbox.Guardian

  channel("stack_box:*", StackboxWeb.StackBoxChannel)

  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    with {:ok, claims} <- Guardian.decode_token(token),
         {:ok, user} <- Guardian.resource_from_claims(claims),
         true <- user.is_active do
      {:ok, assign(socket, :current_user, user)}
    else
      _ -> :error
    end
  end

  def connect(_params, _socket, _connect_info), do: :error

  @impl true
  def id(socket), do: "user_socket:#{socket.assigns.current_user.id}"
end
