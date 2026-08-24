defmodule Stackbox.Repo.Migrations.CreateReactions do
  use Ecto.Migration

  def up do
    execute("""
    CREATE TABLE reactions (
        id           BIGSERIAL PRIMARY KEY,
        stack_box_id BIGINT NOT NULL REFERENCES stack_boxes(id) ON DELETE CASCADE,
        user_id      BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        emoji_code   VARCHAR(64) NOT NULL,
        created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        UNIQUE (stack_box_id, user_id, emoji_code)
    )
    """)

    execute("CREATE INDEX idx_reactions_stack_box ON reactions (stack_box_id)")
  end

  def down do
    execute("DROP TABLE IF EXISTS reactions")
  end
end
