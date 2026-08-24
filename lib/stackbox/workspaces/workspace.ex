defmodule Stackbox.Workspaces.Workspace do
  use Ecto.Schema
  import Ecto.Changeset

  schema "workspaces" do
    field :name, :string
    field :slug, :string
    field :description, :string, default: ""
    field :icon, :string

    belongs_to :owner, Stackbox.Accounts.User

    field :created_at, :utc_datetime, read_after_writes: true
    field :updated_at, :utc_datetime, read_after_writes: true
  end

  @doc false
  def changeset(workspace, attrs) do
    workspace
    |> cast(attrs, [:name, :slug, :description, :icon, :owner_id])
    |> validate_required([:name, :slug, :owner_id])
    |> validate_length(:name, max: 255)
    |> validate_length(:slug, max: 100)
    |> unique_constraint(:slug)
    |> foreign_key_constraint(:owner_id)
  end
end
