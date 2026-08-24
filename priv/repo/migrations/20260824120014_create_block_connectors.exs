defmodule Stackbox.Repo.Migrations.CreateBlockConnectors do
  use Ecto.Migration

  def up do
    execute("""
    CREATE TABLE block_connectors (
        id              BIGSERIAL PRIMARY KEY,
        stack_box_id    BIGINT NOT NULL REFERENCES stack_boxes(id) ON DELETE CASCADE,
        source_block_id BIGINT NOT NULL REFERENCES blocks(id) ON DELETE CASCADE,
        target_block_id BIGINT NOT NULL REFERENCES blocks(id) ON DELETE CASCADE,
        source_anchor   JSONB,
        target_anchor   JSONB,
        label           VARCHAR(255),
        style           JSONB,
        created_by      BIGINT REFERENCES users(id) ON DELETE SET NULL,
        created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        CONSTRAINT block_connectors_distinct_ends_chk CHECK (source_block_id <> target_block_id)
    )
    """)

    execute("CREATE INDEX idx_block_connectors_stack_box ON block_connectors (stack_box_id)")
    execute("CREATE INDEX idx_block_connectors_source ON block_connectors (source_block_id)")
    execute("CREATE INDEX idx_block_connectors_target ON block_connectors (target_block_id)")

    execute("""
    CREATE TRIGGER trg_block_connectors_updated_at
        BEFORE UPDATE ON block_connectors
        FOR EACH ROW EXECUTE FUNCTION set_updated_at()
    """)
  end

  def down do
    execute("DROP TABLE IF EXISTS block_connectors")
  end
end
