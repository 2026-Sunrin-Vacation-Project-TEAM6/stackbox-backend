defmodule Stackbox.StackBoxes.CanvasPresence do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "canvas_presence" do
    belongs_to :stack_box, Stackbox.StackBoxes.StackBox, primary_key: true
    belongs_to :user, Stackbox.Accounts.User, primary_key: true

    field :cursor_x, :float
    field :cursor_y, :float
    field :selection, :map
    field :color, :string

    field :last_seen_at, :utc_datetime, read_after_writes: true
  end

  @doc false
  def changeset(canvas_presence, attrs) do
    canvas_presence
    |> cast(attrs, [:stack_box_id, :user_id, :cursor_x, :cursor_y, :selection, :color, :last_seen_at])
    |> validate_required([:stack_box_id, :user_id])
    |> foreign_key_constraint(:stack_box_id)
    |> foreign_key_constraint(:user_id)
  end
end
