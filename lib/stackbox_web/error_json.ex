defmodule StackboxWeb.ErrorJSON do
  def render(template, _assigns) do
    %{detail: Phoenix.Controller.status_message_from_template(template)}
  end
end
