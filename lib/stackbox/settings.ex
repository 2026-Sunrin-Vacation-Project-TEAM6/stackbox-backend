defmodule Stackbox.Settings do
  @moduledoc false

  def get(key) do
    :stackbox
    |> Application.fetch_env!(:settings)
    |> Keyword.fetch!(key)
  end
end
