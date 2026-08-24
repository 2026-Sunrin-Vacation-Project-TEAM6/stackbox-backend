defmodule Stackbox.Repo.Migrations.CreateAssets do
  use Ecto.Migration

  def up do
    execute("""
    CREATE TABLE assets (
        id           BIGSERIAL PRIMARY KEY,
        stack_box_id BIGINT NOT NULL REFERENCES stack_boxes(id) ON DELETE CASCADE,
        block_id     BIGINT REFERENCES blocks(id) ON DELETE SET NULL,
        name         VARCHAR(255) NOT NULL,
        url          VARCHAR(512) NOT NULL,
        mime_type    VARCHAR(100) NOT NULL,
        size_bytes   BIGINT NOT NULL DEFAULT 0 CHECK (size_bytes >= 0),
        uploaded_by  BIGINT REFERENCES users(id) ON DELETE SET NULL,
        created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
    """)

    execute("CREATE INDEX idx_assets_stack_box ON assets (stack_box_id)")
    execute("CREATE INDEX idx_assets_block ON assets (block_id)")
  end

  def down do
    execute("DROP TABLE IF EXISTS assets")
  end
end
