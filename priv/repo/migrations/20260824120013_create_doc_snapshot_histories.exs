defmodule Stackbox.Repo.Migrations.CreateDocSnapshotHistories do
  use Ecto.Migration

  def up do
    execute("""
    CREATE TABLE doc_snapshot_histories (
        id           BIGSERIAL PRIMARY KEY,
        stack_box_id BIGINT NOT NULL REFERENCES stack_boxes(id) ON DELETE CASCADE,
        blob         BYTEA NOT NULL,
        state        BYTEA,
        expired_at   TIMESTAMPTZ NOT NULL,
        created_by   BIGINT REFERENCES users(id) ON DELETE SET NULL,
        created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
    """)

    execute(
      "CREATE INDEX idx_doc_snapshot_histories_stack_box ON doc_snapshot_histories (stack_box_id, created_at)"
    )
  end

  def down do
    execute("DROP TABLE IF EXISTS doc_snapshot_histories")
  end
end
