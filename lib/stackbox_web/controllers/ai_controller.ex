defmodule StackboxWeb.AIController do
  @moduledoc """
  Mirrors `backend/app/routers/ai.py` (plus the `/ai/edit-text` action from
  Python commit `0b17644`, which pre-dates the divergence point of the
  read-only `backend/` reference checkout but is already wired up in
  `router.ex`). Every action is rate-limited per user (`_enforce_ai_rate_limit`
  in the Python reference), and `/ai/chat`'s system-role message is always
  server-set — the client-supplied `messages` may only carry `"user"`/
  `"assistant"` roles, never `"system"`.
  """

  use StackboxWeb, :controller

  alias Stackbox.AI
  alias Stackbox.Authorization
  alias Stackbox.PptBuilder
  alias Stackbox.RateLimiter
  alias Stackbox.StackBoxes

  action_fallback StackboxWeb.FallbackController

  # Every /ai/* call is billed against our OpenAI key regardless of which
  # user triggers it, so cap usage per user rather than leaving it unbounded.
  @ai_rate_limit 20
  @ai_rate_window_seconds 3600

  @chat_system_prompt "당신은 StackBox 문서 작성을 돕는 어시스턴트입니다. 사용자 요청에 협조적이고 " <>
                        "간결하게 답하세요."

  def summarize(conn, %{"text" => text}) when is_binary(text) do
    current_user = conn.assigns.current_user

    with :ok <- validate_length(text, "text", 20_000),
         :ok <- enforce_ai_rate_limit(current_user),
         {:ok, summary} <-
           complete_or_error(
             "당신은 문서를 간결하게 요약하는 어시스턴트입니다. 핵심만 3~5문장으로 요약하세요.",
             text
           ) do
      json(conn, %{summary: summary})
    end
  end

  def summarize(_conn, _params), do: {:error, :bad_request, "text is required"}

  def fix_code(conn, %{"code" => code} = params) when is_binary(code) do
    current_user = conn.assigns.current_user
    instructions = Map.get(params, "instructions") || "버그를 찾아 수정하고 개선하세요."
    language = params["language"]
    language_hint = if language, do: " (언어: #{language})", else: ""

    system_prompt =
      "당신은 숙련된 소프트웨어 엔지니어입니다. 아래 형식을 정확히 지켜 응답하세요:\n" <>
        "```\n<수정된 코드>\n```\n설명: <한두 문장 설명>"

    user_prompt = "지시사항: #{instructions}#{language_hint}\n\n코드:\n#{code}"

    with :ok <- validate_length(code, "code", 20_000),
         :ok <- validate_length(instructions, "instructions", 2_000),
         :ok <- enforce_ai_rate_limit(current_user),
         {:ok, raw} <- complete_or_error(system_prompt, user_prompt) do
      {fixed_code, explanation} = parse_fix_code_response(raw)
      json(conn, %{fixed_code: fixed_code, explanation: explanation})
    end
  end

  def fix_code(_conn, _params), do: {:error, :bad_request, "code is required"}

  def edit_text(conn, %{"text" => text, "instructions" => instructions})
      when is_binary(text) and is_binary(instructions) do
    current_user = conn.assigns.current_user

    system_prompt =
      "당신은 사용자가 선택한 텍스트를 지시사항에 따라 수정하는 어시스턴트입니다. " <>
        "수정된 텍스트만 출력하고, 다른 설명이나 따옴표, 코드 블록은 포함하지 마세요."

    user_prompt = "지시사항: #{instructions}\n\n텍스트:\n#{text}"

    with :ok <- validate_length(text, "text", 20_000),
         :ok <- validate_length(instructions, "instructions", 2_000),
         :ok <- enforce_ai_rate_limit(current_user),
         {:ok, raw} <- complete_or_error(system_prompt, user_prompt) do
      json(conn, %{edited_text: String.trim(raw)})
    end
  end

  def edit_text(_conn, _params), do: {:error, :bad_request, "text and instructions are required"}

  def draft(conn, %{"prompt" => prompt}) when is_binary(prompt) do
    current_user = conn.assigns.current_user

    with :ok <- validate_length(prompt, "prompt", 4_000),
         :ok <- enforce_ai_rate_limit(current_user),
         {:ok, text} <-
           complete_or_error(
             "당신은 문서 초안을 작성하는 어시스턴트입니다. 마크다운 형식으로 초안을 작성하세요.",
             prompt
           ) do
      json(conn, %{draft: text})
    end
  end

  def draft(_conn, _params), do: {:error, :bad_request, "prompt is required"}

  def chat(conn, %{"messages" => messages}) when is_list(messages) do
    current_user = conn.assigns.current_user

    with {:ok, sanitized} <- sanitize_messages(messages),
         :ok <- enforce_ai_rate_limit(current_user),
         {:ok, reply} <- chat_or_error([system_message() | sanitized]) do
      json(conn, %{reply: reply})
    end
  end

  def chat(_conn, _params), do: {:error, :bad_request, "messages is required"}

  def doc_to_ppt(conn, %{"stack_box_id" => stack_box_id} = params) do
    current_user = conn.assigns.current_user
    num_slides = parse_int(params["num_slides"], 5)

    with :ok <- enforce_ai_rate_limit(current_user),
         {:ok, int_id} <- parse_id(stack_box_id),
         {:ok, stack_box} <- fetch_stack_box(int_id),
         {:ok, _role} <- require_role(stack_box.workspace_id, current_user, :viewer),
         prompt = build_ppt_prompt(stack_box),
         {:ok, {content_type, bytes}} <- build_ppt_or_error(prompt, num_slides) do
      filename = "#{stack_box.name}.pptx"

      conn
      |> put_resp_content_type(content_type)
      |> put_resp_header("content-disposition", "attachment; filename=\"#{filename}\"")
      |> send_resp(:ok, bytes)
    end
  end

  def doc_to_ppt(_conn, _params), do: {:error, :bad_request, "stack_box_id is required"}

  # -- shared helpers ---------------------------------------------------------

  defp enforce_ai_rate_limit(user) do
    case RateLimiter.enforce_rate_limit("ai:#{user.id}", @ai_rate_limit, @ai_rate_window_seconds) do
      :ok ->
        :ok

      {:error, :rate_limited} ->
        {:error, :too_many_requests, "Rate limit exceeded, please slow down and try again later"}

      {:error, _reason} ->
        {:error, :service_unavailable, "Rate limiter is temporarily unavailable"}
    end
  end

  defp complete_or_error(system_prompt, user_prompt) do
    case AI.complete(system_prompt, user_prompt) do
      {:ok, content} -> {:ok, content}
      {:error, reason} -> {:error, :bad_gateway, "AI request failed: #{ai_error_reason(reason)}"}
    end
  end

  defp chat_or_error(messages) do
    case AI.chat(messages) do
      {:ok, content} -> {:ok, content}
      {:error, reason} -> {:error, :bad_gateway, "AI request failed: #{ai_error_reason(reason)}"}
    end
  end

  defp ai_error_reason(:rate_limited), do: "upstream rate limit exceeded"
  defp ai_error_reason(:malformed_response), do: "unexpected response"
  defp ai_error_reason({:upstream_status, status}), do: "status #{status}"
  defp ai_error_reason({:request_failed, _reason}), do: "connection failed"
  defp ai_error_reason(_reason), do: "unknown error"

  defp system_message, do: %{role: "system", content: @chat_system_prompt}

  @doc false
  # payload.messages can only carry "user"/"assistant" roles: the system
  # prompt is always server-set and prepended separately, never accepted
  # from the client, so a client can never override or inject a system
  # message into the conversation sent to OpenAI.
  defp sanitize_messages(messages) when length(messages) in 1..50 do
    Enum.reduce_while(messages, {:ok, []}, fn
      %{"role" => role, "content" => content}, {:ok, acc}
      when role in ["user", "assistant"] and is_binary(content) ->
        if String.length(content) <= 8_000 do
          {:cont, {:ok, [%{role: role, content: content} | acc]}}
        else
          {:halt, {:error, :bad_request, "message content must be at most 8000 characters"}}
        end

      _other, _acc ->
        {:halt,
         {:error, :bad_request,
          "each message must have role \"user\" or \"assistant\" and string content"}}
    end)
    |> case do
      {:ok, acc} -> {:ok, Enum.reverse(acc)}
      error -> error
    end
  end

  defp sanitize_messages(_messages),
    do: {:error, :bad_request, "messages must contain between 1 and 50 items"}

  defp parse_fix_code_response(raw) do
    case String.split(raw, "```") do
      [_only] ->
        {String.trim(raw), ""}

      [_before, code_block | rest] ->
        fixed_code =
          case String.split(code_block, "\n", parts: 2) do
            [_only_line] -> code_block
            [_first_line, remainder] -> remainder
          end

        explanation =
          rest
          |> Enum.join("```")
          |> String.replace("설명:", "")
          |> String.trim()

        {String.trim(fixed_code), explanation}
    end
  end

  defp build_ppt_prompt(stack_box) do
    text =
      stack_box.id
      |> StackBoxes.list_doc_blocks()
      |> Enum.filter(&(&1.type == :markdown))
      |> Enum.map_join("\n\n", & &1.content)

    if text == "", do: stack_box.description, else: text
  end

  defp build_ppt_or_error(prompt, num_slides) do
    case PptBuilder.build(prompt, num_slides) do
      {:ok, result} ->
        {:ok, result}

      {:error, :timeout} ->
        {:error, :gateway_timeout, "ppt_builder timed out"}

      {:error, :unauthorized} ->
        {:error, :service_unavailable, "ppt_builder rejected our credentials"}

      {:error, {:upstream_status, 400}} ->
        {:error, :bad_request, "Unable to build a presentation from this document"}

      {:error, {:upstream_status, 429}} ->
        {:error, :too_many_requests, "ppt_builder is rate limited upstream"}

      {:error, {:upstream_status, 504}} ->
        {:error, :gateway_timeout, "ppt_builder timed out"}

      {:error, {:upstream_status, _status}} ->
        {:error, :bad_gateway, "ppt_builder request failed"}

      {:error, {:request_failed, _reason}} ->
        {:error, :bad_gateway, "ppt_builder is unavailable"}
    end
  end

  defp validate_length(value, field, max) when is_binary(value) do
    if String.length(value) <= max do
      :ok
    else
      {:error, :bad_request, "#{field} must be at most #{max} characters"}
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
      _ -> {:error, :not_found, "StackBox not found"}
    end
  end

  defp parse_id(_), do: {:error, :not_found, "StackBox not found"}

  defp parse_int(nil, default), do: default
  defp parse_int(value, _default) when is_integer(value), do: value

  defp parse_int(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> default
    end
  end

  defp parse_int(_value, default), do: default
end
