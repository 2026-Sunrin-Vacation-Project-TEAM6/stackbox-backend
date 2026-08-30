defmodule Stackbox.Repo.Migrations.CreateDocSnapshots do
  use Ecto.Migration

  def up do
    execute("""
    CREATE TABLE doc_snapshots (
        stack_box_id BIGINT PRIMARY KEY REFERENCES stack_boxes(id) ON DELETE CASCADE,
        blob         BYTEA NOT NULL,
        state        BYTEA,
        size         BIGINT NOT NULL DEFAULT 0 CHECK (size >= 0),
        version      BIGINT NOT NULL DEFAULT 0,
        created_by   BIGINT REFERENCES users(id) ON DELETE SET NULL,
        updated_by   BIGINT REFERENCES users(id) ON DELETE SET NULL,
        created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
    """)

    execute("CREATE INDEX idx_doc_snapshots_updated ON doc_snapshots (updated_at)")

    execute("""
    CREATE TRIGGER trg_doc_snapshots_updated_at
        BEFORE UPDATE ON doc_snapshots
        FOR EACH ROW EXECUTE FUNCTION set_updated_at()
    """)
  end

  def down do
    execute("DROP TABLE IF EXISTS doc_snapshots")
  end
end
