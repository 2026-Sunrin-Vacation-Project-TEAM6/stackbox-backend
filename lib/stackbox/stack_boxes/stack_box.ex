defmodule Stackbox.StackBoxes.StackBox do
  use Ecto.Schema
  import Ecto.Changeset

  schema "stack_boxes" do
    field :type, Ecto.Enum, values: [:folder, :page, :canvas, :edgeless], default: :folder
    field :name, :string
    field :description, :string, default: ""
    field :icon, :string
    field :cover_url, :string
    field :sort_order, :integer, default: 0

    belongs_to :workspace, Stackbox.Workspaces.Workspace
    belongs_to :parent, __MODULE__

    field :created_by, :id
    belongs_to :created_by_user, Stackbox.Accounts.User, foreign_key: :created_by, define_field: false

    field :updated_by, :id
    belongs_to :updated_by_user, Stackbox.Accounts.User, foreign_key: :updated_by, define_field: false

    field :created_at, :utc_datetime, read_after_writes: true
    field :updated_at, :utc_datetime, read_after_writes: true
  end

  @doc false
  def changeset(stack_box, attrs) do
    stack_box
    |> cast(attrs, [
      :workspace_id,
      :parent_id,
      :type,
      :name,
      :description,
      :icon,
      :cover_url,
      :sort_order,
      :created_by,
      :updated_by
    ])
    |> validate_required([:workspace_id, :type, :name])
    |> validate_length(:name, max: 255)
    |> foreign_key_constraint(:workspace_id)
    |> foreign_key_constraint(:parent_id)
    |> foreign_key_constraint(:created_by)
    |> foreign_key_constraint(:updated_by)
  end
end
