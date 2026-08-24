defmodule Stackbox.Repo.Migrations.CreateStackBoxes do
  use Ecto.Migration

  def up do
    execute("""
    CREATE TABLE stack_boxes (
        id           BIGSERIAL PRIMARY KEY,
        workspace_id BIGINT NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
        parent_id    BIGINT REFERENCES stack_boxes(id) ON DELETE CASCADE,
        type         stack_box_type NOT NULL DEFAULT 'folder',
        name         VARCHAR(255) NOT NULL,
        description  TEXT NOT NULL DEFAULT '',
        icon         VARCHAR(64),
        cover_url    VARCHAR(512),
        sort_order   INT NOT NULL DEFAULT 0,
        created_by   BIGINT REFERENCES users(id) ON DELETE SET NULL,
        updated_by   BIGINT REFERENCES users(id) ON DELETE SET NULL,
        created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
    """)

    execute("CREATE INDEX idx_stack_boxes_workspace ON stack_boxes (workspace_id)")
    execute("CREATE INDEX idx_stack_boxes_parent ON stack_boxes (parent_id)")

    execute(
      "CREATE INDEX idx_stack_boxes_workspace_parent_sort ON stack_boxes (workspace_id, parent_id, sort_order)"
    )

    execute("CREATE INDEX idx_stack_boxes_type ON stack_boxes (type)")

    execute("""
    CREATE TRIGGER trg_stack_boxes_updated_at
        BEFORE UPDATE ON stack_boxes
        FOR EACH ROW EXECUTE FUNCTION set_updated_at()
    """)
  end

  def down do
    execute("DROP TABLE IF EXISTS stack_boxes")
  end
end
