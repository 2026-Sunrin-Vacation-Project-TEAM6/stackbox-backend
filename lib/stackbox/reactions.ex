defmodule Stackbox.Reactions do
  @moduledoc """
  Context for `reactions`, mirroring `backend/app/routers/reactions.py`.
  """

  import Ecto.Query, warn: false

  alias Stackbox.Repo
  alias Stackbox.Reactions.Reaction

  def list_reactions(stack_box_id) do
    from(r in Reaction, where: r.stack_box_id == ^stack_box_id)
    |> Repo.all()
  end

  def get_reaction(stack_box_id, user_id, emoji_code) do
    Repo.get_by(Reaction, stack_box_id: stack_box_id, user_id: user_id, emoji_code: emoji_code)
  end

  def add_reaction(attrs) do
    %Reaction{}
    |> Reaction.changeset(attrs)
    |> Repo.insert()
  end

  def remove_reaction(%Reaction{} = reaction), do: Repo.delete(reaction)

  def remove_reaction(stack_box_id, user_id, emoji_code) do
    case get_reaction(stack_box_id, user_id, emoji_code) do
      nil -> {:ok, nil}
      %Reaction{} = reaction -> Repo.delete(reaction)
    end
  end
end
