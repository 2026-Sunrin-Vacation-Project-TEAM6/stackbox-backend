defmodule Stackbox.Repo.Migrations.CreateWorkspaces do
  use Ecto.Migration

  def up do
    execute("""
    CREATE TABLE workspaces (
        id          BIGSERIAL PRIMARY KEY,
        name        VARCHAR(255) NOT NULL,
        slug        VARCHAR(100) NOT NULL UNIQUE,
        description TEXT NOT NULL DEFAULT '',
        icon        VARCHAR(64),
        owner_id    BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
        created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
    """)

    execute("CREATE INDEX idx_workspaces_owner ON workspaces (owner_id)")
    execute("CREATE INDEX idx_workspaces_slug ON workspaces (slug)")

    execute("""
    CREATE TRIGGER trg_workspaces_updated_at
        BEFORE UPDATE ON workspaces
        FOR EACH ROW EXECUTE FUNCTION set_updated_at()
    """)
  end

  def down do
    execute("DROP TABLE IF EXISTS workspaces")
  end
end
