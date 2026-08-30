defmodule Stackbox.Repo.Migrations.CreateBlockBindings do
  use Ecto.Migration

  def up do
    execute("""
    CREATE TABLE block_bindings (
        id                  BIGSERIAL PRIMARY KEY,
        source_block_id     BIGINT NOT NULL REFERENCES blocks(id) ON DELETE CASCADE,
        target_stack_box_id BIGINT REFERENCES stack_boxes(id) ON DELETE CASCADE,
        target_block_id     BIGINT REFERENCES blocks(id) ON DELETE CASCADE,
        binding_type        VARCHAR(32) NOT NULL DEFAULT 'link',
        created_by          BIGINT REFERENCES users(id) ON DELETE SET NULL,
        created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        CONSTRAINT block_bindings_target_chk CHECK (
            target_stack_box_id IS NOT NULL OR target_block_id IS NOT NULL
        )
    )
    """)

    execute("CREATE INDEX idx_block_bindings_source ON block_bindings (source_block_id)")
    execute("CREATE INDEX idx_block_bindings_target_box ON block_bindings (target_stack_box_id)")
  end

  def down do
    execute("DROP TABLE IF EXISTS block_bindings")
  end
end
