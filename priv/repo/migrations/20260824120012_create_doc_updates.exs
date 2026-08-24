defmodule Stackbox.Repo.Migrations.CreateDocUpdates do
  use Ecto.Migration

  def up do
    execute("""
    CREATE TABLE doc_updates (
        id           BIGSERIAL PRIMARY KEY,
        stack_box_id BIGINT NOT NULL REFERENCES stack_boxes(id) ON DELETE CASCADE,
        blob         BYTEA NOT NULL,
        seq          BIGINT NOT NULL,
        created_by   BIGINT REFERENCES users(id) ON DELETE SET NULL,
        created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        UNIQUE (stack_box_id, seq)
    )
    """)

    execute("CREATE INDEX idx_doc_updates_stack_box_created ON doc_updates (stack_box_id, created_at)")
  end

  def down do
    execute("DROP TABLE IF EXISTS doc_updates")
  end
end
