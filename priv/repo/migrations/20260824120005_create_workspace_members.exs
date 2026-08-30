defmodule Stackbox.Repo.Migrations.CreateWorkspaceMembers do
  use Ecto.Migration

  def up do
    execute("""
    CREATE TABLE workspace_members (
        id           BIGSERIAL PRIMARY KEY,
        workspace_id BIGINT NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
        user_id      BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        role         workspace_role NOT NULL DEFAULT 'viewer',
        invited_by   BIGINT REFERENCES users(id) ON DELETE SET NULL,
        joined_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        UNIQUE (workspace_id, user_id)
    )
    """)

    execute("CREATE INDEX idx_workspace_members_workspace ON workspace_members (workspace_id)")
    execute("CREATE INDEX idx_workspace_members_user ON workspace_members (user_id)")
  end

  def down do
    execute("DROP TABLE IF EXISTS workspace_members")
  end
end
