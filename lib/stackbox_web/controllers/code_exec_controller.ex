defmodule StackboxWeb.CodeExecController do
  @moduledoc """
  Mirrors `backend/app/routers/code_exec.py`. Delegates untrusted code
  execution to the `web_worker` Rust `code_runner` binary over HTTP
  (`Stackbox.CodeRunner`) rather than running anything locally.
  """

  use StackboxWeb, :controller

  alias Stackbox.Authorization
  alias Stackbox.CodeRunner
  alias Stackbox.StackBoxes

  action_fallback StackboxWeb.FallbackController

  def run_block(conn, %{"id" => id} = params) do
    current_user = conn.assigns.current_user

    with {:ok, block} <- fetch_block(id),
         :ok <- ensure_code_block(block),
         {:ok, stack_box} <- fetch_stack_box(block.stack_box_id),
         {:ok, _role} <- require_role(stack_box.workspace_id, current_user, :editor),
         language = block.language || "python",
         {:ok, result} <- run_or_error(language, block.content, params["stdin"]),
         attrs = %{
           block_id: block.id,
           language: language,
           stdout: result.stdout,
           stderr: exec_stderr(result),
           exit_code: result.exit_code,
           duration_ms: result.duration_ms
         },
         {:ok, code_run} <- StackBoxes.create_code_run(attrs, current_user.id) do
      conn |> put_status(:created) |> json(code_run_json(code_run))
    end
  end

  def run_block(_conn, _params), do: {:error, :not_found, "Block not found"}

  def list_runs(conn, %{"id" => id}) do
    with {:ok, block} <- fetch_block(id),
         {:ok, stack_box} <- fetch_stack_box(block.stack_box_id),
         {:ok, _role} <- require_role(stack_box.workspace_id, conn.assigns.current_user, :viewer) do
      runs = StackBoxes.list_code_runs(block.id)
      json(conn, Enum.map(runs, &code_run_json/1))
    end
  end

  defp ensure_code_block(%{type: :code}), do: :ok
  defp ensure_code_block(_block), do: {:error, :bad_request, "Block is not a code block"}

  # `block.content` is stripped before sending it to code_runner: leading/
  # trailing whitespace on the whole script (e.g. from pasted or copy-typed
  # code) causes spurious IndentationErrors in Python, mirroring
  # `backend/app/routers/code_exec.py`'s `block.content.strip()` (Python
  # commit 0b17644).
  defp run_or_error(language, code, stdin) do
    case CodeRunner.execute(language, String.trim(code), stdin) do
      {:ok, result} ->
        {:ok, result}

      {:error, reason} ->
        {:error, :bad_gateway, "code runner unavailable: #{upstream_reason(reason)}"}
    end
  end

  defp upstream_reason(:timeout), do: "timed out"
  defp upstream_reason(:unauthorized), do: "unauthorized"
  defp upstream_reason(:malformed_response), do: "unexpected response"
  defp upstream_reason({:upstream_status, status, message}), do: "status #{status}: #{message}"
  defp upstream_reason({:request_failed, _reason}), do: "connection failed"
  defp upstream_reason(_reason), do: "unknown error"

  # `compile_error` (from a newer `code_runner` build compiling C/C++/Rust)
  # has no dedicated column on `code_runs`; when present, fold it into
  # `stderr` so the information isn't silently dropped instead of adding a
  # schema column for a field that may not even be present in the deployed
  # `code_runner` build (see `Stackbox.CodeRunner`'s moduledoc).
  defp exec_stderr(%{compile_error: nil, stderr: stderr}), do: stderr
  defp exec_stderr(%{compile_error: "", stderr: stderr}), do: stderr
  defp exec_stderr(%{compile_error: compile_error, stderr: ""}), do: compile_error

  defp exec_stderr(%{compile_error: compile_error, stderr: stderr}),
    do: stderr <> "\n\n" <> compile_error

  defp fetch_block(id) do
    with {:ok, int_id} <- parse_id(id) do
      case StackBoxes.get_doc_block(int_id) do
        nil -> {:error, :not_found, "Block not found"}
        block -> {:ok, block}
      end
    end
  end

  defp fetch_stack_box(id) do
    case StackBoxes.get_stack_box(id) do
      nil -> {:error, :not_found, "StackBox not found"}
      stack_box -> {:ok, stack_box}
    end
  end

  defp require_role(workspace_id, user, minimum) do
    case Authorization.require_workspace_role(workspace_id, user, minimum) do
      {:ok, role} -> {:ok, role}
      {:error, :forbidden} -> {:error, :forbidden, "Insufficient workspace permissions"}
    end
  end

  defp parse_id(id) when is_integer(id), do: {:ok, id}

  defp parse_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {int_id, ""} -> {:ok, int_id}
      _ -> {:error, :not_found, "Block not found"}
    end
  end

  defp parse_id(_), do: {:error, :not_found, "Block not found"}

  defp code_run_json(code_run) do
    %{
      id: code_run.id,
      block_id: code_run.block_id,
      language: code_run.language,
      stdout: code_run.stdout,
      stderr: code_run.stderr,
      exit_code: code_run.exit_code,
      duration_ms: code_run.duration_ms,
      executed_by: code_run.executed_by,
      created_at: code_run.created_at
    }
  end
end
