defmodule Stackbox.Repo.Migrations.CreateCanvasSettings do
  use Ecto.Migration

  def up do
    execute("""
    CREATE TABLE canvas_settings (
        stack_box_id  BIGINT PRIMARY KEY REFERENCES stack_boxes(id) ON DELETE CASCADE,
        viewport      JSONB,
        grid_enabled  BOOLEAN NOT NULL DEFAULT TRUE,
        snap_enabled  BOOLEAN NOT NULL DEFAULT TRUE,
        background    JSONB,
        updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
    """)

    execute("""
    CREATE TRIGGER trg_canvas_settings_updated_at
        BEFORE UPDATE ON canvas_settings
        FOR EACH ROW EXECUTE FUNCTION set_updated_at()
    """)
  end

  def down do
    execute("DROP TABLE IF EXISTS canvas_settings")
  end
end
