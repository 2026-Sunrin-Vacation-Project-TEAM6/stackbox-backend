defmodule Stackbox.CodeRunner do
  @moduledoc """
  Client for the `web_worker` Rust `code_runner` binary's `POST /execute`,
  mirroring `backend/app/routers/code_exec.py`. The response is decoded
  defensively: `compile_error`/`cached`/`cache_key` are newer fields that may
  or may not be present depending on which `web_worker` build is deployed,
  so only `stdout`/`stderr`/`exit_code`/`duration_ms` are required.
  """

  alias Stackbox.Settings

  @doc """
  Runs `code` (already trimmed by the caller) for `language`, with optional
  `stdin`. Returns `{:ok, result}` where `result` has string-keyed
  `stdout`/`stderr`/`exit_code`/`duration_ms`, plus `compile_error` (`nil` if
  absent from the response).
  """
  def execute(language, code, stdin) do
    req()
    |> Req.post(
      url: base_url() <> "/execute",
      headers: [{"x-code-runner-token", Settings.get(:code_runner_auth_token)}],
      json: %{language: language, code: code, stdin: stdin}
    )
    |> case do
      {:ok, %Req.Response{status: 200, body: %{"stdout" => _} = body}} ->
        {:ok, normalize(body)}

      {:ok, %Req.Response{status: 200}} ->
        {:error, :malformed_response}

      {:ok, %Req.Response{status: 401}} ->
        {:error, :unauthorized}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:upstream_status, status, error_message(body)}}

      {:error, %Req.TransportError{reason: :timeout}} ->
        {:error, :timeout}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  defp normalize(body) do
    %{
      stdout: Map.get(body, "stdout", ""),
      stderr: Map.get(body, "stderr", ""),
      exit_code: Map.get(body, "exit_code", 0),
      duration_ms: Map.get(body, "duration_ms", 0),
      compile_error: Map.get(body, "compile_error"),
      cached: Map.get(body, "cached", false)
    }
  end

  defp error_message(%{"error" => message}) when is_binary(message), do: message
  defp error_message(_), do: "code runner request failed"

  defp base_url, do: String.trim_trailing(Settings.get(:code_runner_url), "/")

  defp req, do: Req.new(Application.get_env(:stackbox, :code_runner_req_options, []))
end
