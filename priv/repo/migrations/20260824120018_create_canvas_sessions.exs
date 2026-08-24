defmodule Stackbox.Repo.Migrations.CreateCanvasSessions do
  use Ecto.Migration

  def up do
    execute("""
    CREATE TABLE canvas_sessions (
        id           BIGSERIAL PRIMARY KEY,
        stack_box_id BIGINT NOT NULL REFERENCES stack_boxes(id) ON DELETE CASCADE,
        share_token  VARCHAR(64) NOT NULL UNIQUE,
        started_by   BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        is_active    BOOLEAN NOT NULL DEFAULT TRUE,
        expires_at   TIMESTAMPTZ,
        created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
    """)

    execute("CREATE INDEX idx_canvas_sessions_stack_box ON canvas_sessions (stack_box_id)")
  end

  def down do
    execute("DROP TABLE IF EXISTS canvas_sessions")
  end
end
