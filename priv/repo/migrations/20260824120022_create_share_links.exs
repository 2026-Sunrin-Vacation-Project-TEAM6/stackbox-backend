defmodule Stackbox.Repo.Migrations.CreateShareLinks do
  use Ecto.Migration

  def up do
    execute("""
    CREATE TABLE share_links (
        id           BIGSERIAL PRIMARY KEY,
        stack_box_id BIGINT NOT NULL REFERENCES stack_boxes(id) ON DELETE CASCADE,
        token        VARCHAR(64) NOT NULL UNIQUE,
        permission   workspace_role NOT NULL DEFAULT 'viewer',
        password_hash VARCHAR(255),
        expires_at   TIMESTAMPTZ,
        created_by   BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
    """)

    execute("CREATE INDEX idx_share_links_stack_box ON share_links (stack_box_id)")
  end

  def down do
    execute("DROP TABLE IF EXISTS share_links")
  end
end
