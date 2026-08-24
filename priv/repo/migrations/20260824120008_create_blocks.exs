defmodule Stackbox.Repo.Migrations.CreateBlocks do
  use Ecto.Migration

  def up do
    execute("""
    CREATE TABLE blocks (
        id              BIGSERIAL PRIMARY KEY,
        stack_box_id    BIGINT NOT NULL REFERENCES stack_boxes(id) ON DELETE CASCADE,
        parent_block_id BIGINT REFERENCES blocks(id) ON DELETE CASCADE,
        type            VARCHAR(50) NOT NULL,
        content         JSONB,
        x               DOUBLE PRECISION,
        y               DOUBLE PRECISION,
        width           DOUBLE PRECISION,
        height          DOUBLE PRECISION,
        rotation        DOUBLE PRECISION NOT NULL DEFAULT 0,
        z_index         INT NOT NULL DEFAULT 0,
        sort_order      INT NOT NULL DEFAULT 0,
        is_locked       BOOLEAN NOT NULL DEFAULT FALSE,
        created_by      BIGINT REFERENCES users(id) ON DELETE SET NULL,
        updated_by      BIGINT REFERENCES users(id) ON DELETE SET NULL,
        created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
    """)

    execute("CREATE INDEX idx_blocks_stack_box ON blocks (stack_box_id)")
    execute("CREATE INDEX idx_blocks_parent ON blocks (parent_block_id)")
    execute("CREATE INDEX idx_blocks_stack_box_sort ON blocks (stack_box_id, sort_order)")
    execute("CREATE INDEX idx_blocks_stack_box_z ON blocks (stack_box_id, z_index)")
    execute("CREATE INDEX idx_blocks_content ON blocks USING GIN (content)")

    execute("""
    CREATE TRIGGER trg_blocks_updated_at
        BEFORE UPDATE ON blocks
        FOR EACH ROW EXECUTE FUNCTION set_updated_at()
    """)
  end

  def down do
    execute("DROP TABLE IF EXISTS blocks")
  end
end
