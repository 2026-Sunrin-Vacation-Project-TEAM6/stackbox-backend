defmodule Stackbox.Repo.Migrations.CreateCommentReplies do
  use Ecto.Migration

  def up do
    execute("""
    CREATE TABLE comment_replies (
        id           BIGSERIAL PRIMARY KEY,
        comment_id   BIGINT NOT NULL REFERENCES comments(id) ON DELETE CASCADE,
        stack_box_id BIGINT NOT NULL REFERENCES stack_boxes(id) ON DELETE CASCADE,
        user_id      BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        content      JSONB NOT NULL,
        created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        deleted_at   TIMESTAMPTZ
    )
    """)

    execute("CREATE INDEX idx_comment_replies_comment ON comment_replies (comment_id, created_at)")
    execute("CREATE INDEX idx_comment_replies_stack_box ON comment_replies (stack_box_id)")

    execute("""
    CREATE TRIGGER trg_comment_replies_updated_at
        BEFORE UPDATE ON comment_replies
        FOR EACH ROW EXECUTE FUNCTION set_updated_at()
    """)
  end

  def down do
    execute("DROP TABLE IF EXISTS comment_replies")
  end
end
