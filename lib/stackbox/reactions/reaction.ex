defmodule Stackbox.Reactions.Reaction do
  use Ecto.Schema
  import Ecto.Changeset

  schema "reactions" do
    belongs_to :stack_box, Stackbox.StackBoxes.StackBox
    belongs_to :user, Stackbox.Accounts.User

    field :emoji_code, :string

    field :created_at, :utc_datetime, read_after_writes: true
  end

  @doc false
  def changeset(reaction, attrs) do
    reaction
    |> cast(attrs, [:stack_box_id, :user_id, :emoji_code])
    |> validate_required([:stack_box_id, :user_id, :emoji_code])
    |> validate_length(:emoji_code, max: 64)
    |> unique_constraint([:stack_box_id, :user_id, :emoji_code])
    |> foreign_key_constraint(:stack_box_id)
    |> foreign_key_constraint(:user_id)
  end
end
