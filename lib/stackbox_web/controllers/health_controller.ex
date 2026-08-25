defmodule StackboxWeb.HealthController do
  @moduledoc "Mirrors `backend/app/routers/health.py`."

  use StackboxWeb, :controller

  def show(conn, _params), do: json(conn, %{status: "ok"})
end
