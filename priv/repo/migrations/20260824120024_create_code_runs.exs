defmodule Stackbox.Repo.Migrations.CreateCodeRuns do
  use Ecto.Migration

  def up do
    execute("""
    CREATE TABLE code_runs (
        id          BIGSERIAL PRIMARY KEY,
        block_id    BIGINT NOT NULL REFERENCES doc_blocks(id) ON DELETE CASCADE,
        language    VARCHAR(32) NOT NULL,
        stdout      TEXT NOT NULL DEFAULT '',
        stderr      TEXT NOT NULL DEFAULT '',
        exit_code   INT NOT NULL DEFAULT 0,
        duration_ms INT NOT NULL DEFAULT 0,
        executed_by BIGINT REFERENCES users(id) ON DELETE SET NULL,
        created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
    """)

    execute("CREATE INDEX idx_code_runs_block ON code_runs (block_id, created_at)")
  end

  def down do
    execute("DROP TABLE IF EXISTS code_runs")
  end
end
