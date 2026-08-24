defmodule Stackbox.Repo.Migrations.CreateDocBlocks do
  use Ecto.Migration

  def up do
    execute("""
    CREATE TABLE doc_blocks (
        id           BIGSERIAL PRIMARY KEY,
        stack_box_id BIGINT NOT NULL REFERENCES stack_boxes(id) ON DELETE CASCADE,
        type         block_type NOT NULL DEFAULT 'markdown',
        language     VARCHAR(32),
        content      TEXT NOT NULL DEFAULT '',
        sort_order   INT NOT NULL DEFAULT 0,
        pos_x        DOUBLE PRECISION,
        pos_y        DOUBLE PRECISION,
        width        DOUBLE PRECISION,
        height       DOUBLE PRECISION,
        created_by   BIGINT REFERENCES users(id) ON DELETE SET NULL,
        updated_by   BIGINT REFERENCES users(id) ON DELETE SET NULL,
        created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
    """)

    execute("CREATE INDEX idx_doc_blocks_stack_box_sort ON doc_blocks (stack_box_id, sort_order)")

    execute("""
    CREATE TRIGGER trg_doc_blocks_updated_at
        BEFORE UPDATE ON doc_blocks
        FOR EACH ROW EXECUTE FUNCTION set_updated_at()
    """)
  end

  def down do
    execute("DROP TABLE IF EXISTS doc_blocks")
  end
end
