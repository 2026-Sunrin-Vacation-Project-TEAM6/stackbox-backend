defmodule Stackbox.Repo.Migrations.CreateCanvasPresence do
  use Ecto.Migration

  def up do
    execute("""
    CREATE TABLE canvas_presence (
        stack_box_id BIGINT NOT NULL REFERENCES stack_boxes(id) ON DELETE CASCADE,
        user_id      BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        cursor_x     DOUBLE PRECISION,
        cursor_y     DOUBLE PRECISION,
        selection    JSONB,
        color        VARCHAR(32),
        last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        PRIMARY KEY (stack_box_id, user_id)
    )
    """)

    execute("CREATE INDEX idx_canvas_presence_last_seen ON canvas_presence (last_seen_at)")
  end

  def down do
    execute("DROP TABLE IF EXISTS canvas_presence")
  end
end
