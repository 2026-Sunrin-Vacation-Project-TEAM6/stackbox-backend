defmodule Stackbox.Cors do
  @moduledoc """
  Reads the CORS allowed-origin list from the application settings at request
  time. CORSPlug accepts a zero-arity function for `:origin` (evaluated per
  request), and a named function reference is used so it can be passed through
  `plug/2` (anonymous functions cannot be escaped into the plug pipeline).
  """
  def origins do
    :stackbox
    |> Application.get_env(:settings, [])
    |> Keyword.get(:cors_allowed_origins, "")
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end
end