defmodule Stackbox.AI do
  @moduledoc """
  OpenAI chat-completions client, mirroring `backend/app/ai_client.py`.
  Calls OpenAI (or an OpenAI-compatible endpoint, via `OPENAI_BASE_URL`)
  directly over HTTP with `Req`.
  """

  alias Stackbox.Settings

  @default_base_url "https://api.openai.com/v1"

  @doc "Single-turn completion: a system prompt plus one user prompt."
  def complete(system_prompt, user_prompt) do
    chat([
      %{role: "system", content: system_prompt},
      %{role: "user", content: user_prompt}
    ])
  end

  @doc "Sends `messages` (each `%{role: ..., content: ...}`) as-is to the chat completions endpoint."
  def chat(messages) do
    req()
    |> Req.post(
      url: base_url() <> "/chat/completions",
      headers: [{"authorization", "Bearer #{Settings.get(:openai_api_key)}"}],
      json: %{model: Settings.get(:openai_model), messages: messages}
    )
    |> handle_response()
  end

  defp handle_response({:ok, %Req.Response{status: status, body: body}})
       when status in 200..299 do
    case body do
      %{"choices" => [%{"message" => %{"content" => content}} | _]} when is_binary(content) ->
        {:ok, content}

      _ ->
        {:error, :malformed_response}
    end
  end

  defp handle_response({:ok, %Req.Response{status: 429}}), do: {:error, :rate_limited}

  defp handle_response({:ok, %Req.Response{status: status}}),
    do: {:error, {:upstream_status, status}}

  defp handle_response({:error, reason}), do: {:error, {:request_failed, reason}}

  defp base_url do
    case Settings.get(:openai_base_url) do
      base when base in [nil, ""] -> @default_base_url
      base -> String.trim_trailing(base, "/")
    end
  end

  defp req, do: Req.new(Application.get_env(:stackbox, :openai_req_options, []))
end
