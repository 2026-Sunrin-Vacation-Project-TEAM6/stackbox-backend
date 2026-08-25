defmodule StackboxWeb.FallbackController do
  @moduledoc """
  Translates `{:error, ...}` tuples returned from controller actions into
  JSON error responses, mirroring the `HTTPException(status_code, detail)`
  pattern used throughout the FastAPI reference (`backend/app/routers/*.py`).
  """

  use StackboxWeb, :controller

  def call(conn, {:error, :not_found, message}) do
    conn |> put_status(:not_found) |> json(%{detail: message})
  end

  def call(conn, {:error, :forbidden, message}) do
    conn |> put_status(:forbidden) |> json(%{detail: message})
  end

  def call(conn, {:error, :bad_request, message}) do
    conn |> put_status(:bad_request) |> json(%{detail: message})
  end

  def call(conn, {:error, :conflict, message}) do
    conn |> put_status(:conflict) |> json(%{detail: message})
  end

  def call(conn, {:error, :unauthorized, message}) do
    conn |> put_status(:unauthorized) |> json(%{detail: message})
  end

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{errors: changeset_errors(changeset)})
  end

  defp changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
