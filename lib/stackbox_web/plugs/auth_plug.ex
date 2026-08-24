defmodule StackboxWeb.Plugs.AuthPlug do
  @moduledoc """
  Extracts and verifies the `Authorization: Bearer <token>` header, mirroring
  `backend/app/dependencies.py`'s `get_current_user`. Assigns `:current_user`
  on success, or halts with 401 (matching the Python "Could not validate
  credentials" detail) on any failure.
  """

  import Plug.Conn

  alias Stackbox.Guardian

  def init(opts), do: opts

  def call(conn, _opts) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, claims} <- Guardian.decode_token(token),
         {:ok, user} <- Guardian.resource_from_claims(claims),
         true <- user.is_active do
      assign(conn, :current_user, user)
    else
      _ -> unauthorized(conn)
    end
  end

  defp unauthorized(conn) do
    conn
    |> put_resp_header("www-authenticate", "Bearer")
    |> put_status(:unauthorized)
    |> Phoenix.Controller.json(%{detail: "Could not validate credentials"})
    |> halt()
  end
end
