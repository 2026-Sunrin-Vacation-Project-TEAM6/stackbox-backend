defmodule Stackbox.Repo.Migrations.CreateWorkspaceInvitations do
  use Ecto.Migration

  def up do
    execute("""
    CREATE TABLE workspace_invitations (
        id           BIGSERIAL PRIMARY KEY,
        workspace_id BIGINT NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
        email        VARCHAR(255) NOT NULL,
        role         workspace_role NOT NULL DEFAULT 'viewer',
        token_hash   VARCHAR(255) NOT NULL UNIQUE,
        invited_by   BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        expires_at   TIMESTAMPTZ NOT NULL,
        accepted_at  TIMESTAMPTZ,
        created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        UNIQUE (workspace_id, email)
    )
    """)

    execute("CREATE INDEX idx_workspace_invitations_workspace ON workspace_invitations (workspace_id)")
    execute("CREATE INDEX idx_workspace_invitations_email ON workspace_invitations (email)")
  end

  def down do
    execute("DROP TABLE IF EXISTS workspace_invitations")
  end
end
