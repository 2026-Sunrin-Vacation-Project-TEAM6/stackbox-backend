defmodule StackboxWeb.AIController do
  @moduledoc """
  Placeholder for `backend/app/routers/ai.py`. No Elixir OpenAI client
  context has been ported yet (no equivalent of `app/ai_client.py`), so
  these actions explicitly return 501 rather than fabricate an unverified
  LLM integration.
  """

  use StackboxWeb, :controller

  def summarize(conn, _params), do: not_implemented(conn)
  def fix_code(conn, _params), do: not_implemented(conn)
  def edit_text(conn, _params), do: not_implemented(conn)
  def draft(conn, _params), do: not_implemented(conn)
  def chat(conn, _params), do: not_implemented(conn)
  def doc_to_ppt(conn, _params), do: not_implemented(conn)

  defp not_implemented(conn) do
    conn |> put_status(:not_implemented) |> json(%{detail: "Not implemented yet"})
  end
end
