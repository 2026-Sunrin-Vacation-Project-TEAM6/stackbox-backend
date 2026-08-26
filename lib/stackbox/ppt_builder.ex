defmodule Stackbox.PptBuilder do
  @moduledoc """
  Client for the `web_worker` Rust `ppt_builder` binary's `POST /build`.
  Unlike the other `/ai/*` actions, `doc-to-ppt` does not call OpenAI
  directly from this app: `ppt_builder` itself builds the slide outline via
  OpenAI and renders the `.pptx`, so this module only delegates the prompt
  and returns the resulting bytes.
  """

  alias Stackbox.Settings

  @doc """
  Builds a presentation from `prompt`/`num_slides` and returns
  `{:ok, {content_type, pptx_bytes}}` on success.
  """
  def build(prompt, num_slides) do
    req()
    |> Req.post(
      url: base_url() <> "/build",
      headers: [{"x-ppt-builder-token", Settings.get(:ppt_worker_auth_token)}],
      json: %{prompt: prompt, num_slides: num_slides}
    )
    |> case do
      {:ok, %Req.Response{status: 200, body: body} = resp} when is_binary(body) ->
        content_type =
          Req.Response.get_header(resp, "content-type")
          |> List.first() ||
            "application/vnd.openxmlformats-officedocument.presentationml.presentation"

        {:ok, {content_type, body}}

      {:ok, %Req.Response{status: 401}} ->
        {:error, :unauthorized}

      {:ok, %Req.Response{status: status}} ->
        {:error, {:upstream_status, status}}

      {:error, %Req.TransportError{reason: :timeout}} ->
        {:error, :timeout}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  defp base_url, do: String.trim_trailing(Settings.get(:ppt_worker_url), "/")

  defp req, do: Req.new(Application.get_env(:stackbox, :ppt_builder_req_options, []))
end
