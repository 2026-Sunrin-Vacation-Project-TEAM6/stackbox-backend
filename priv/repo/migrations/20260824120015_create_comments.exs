defmodule Stackbox.Repo.Migrations.CreateComments do
  use Ecto.Migration

  def up do
    execute("""
    CREATE TABLE comments (
        id           BIGSERIAL PRIMARY KEY,
        stack_box_id BIGINT NOT NULL REFERENCES stack_boxes(id) ON DELETE CASCADE,
        block_id     BIGINT REFERENCES blocks(id) ON DELETE SET NULL,
        user_id      BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        anchor_x     DOUBLE PRECISION,
        anchor_y     DOUBLE PRECISION,
        content      JSONB NOT NULL,
        is_resolved  BOOLEAN NOT NULL DEFAULT FALSE,
        created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        deleted_at   TIMESTAMPTZ
    )
    """)

    execute("CREATE INDEX idx_comments_stack_box ON comments (stack_box_id, created_at)")
    execute("CREATE INDEX idx_comments_block ON comments (block_id)")
    execute("CREATE INDEX idx_comments_user ON comments (user_id)")

    execute("""
    CREATE TRIGGER trg_comments_updated_at
        BEFORE UPDATE ON comments
        FOR EACH ROW EXECUTE FUNCTION set_updated_at()
    """)
  end

  def down do
    execute("DROP TABLE IF EXISTS comments")
  end
end
