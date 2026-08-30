defmodule Stackbox.Repo.Migrations.CreateStackBoxDocs do
  use Ecto.Migration

  def up do
    execute("""
    CREATE TABLE stack_box_docs (
        stack_box_id  BIGINT PRIMARY KEY REFERENCES stack_boxes(id) ON DELETE CASCADE,
        mode          doc_mode NOT NULL DEFAULT 'page',
        title         VARCHAR(255),
        summary       TEXT,
        is_published  BOOLEAN NOT NULL DEFAULT FALSE,
        published_at  TIMESTAMPTZ,
        is_blocked    BOOLEAN NOT NULL DEFAULT FALSE,
        updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
    """)

    execute("""
    CREATE TRIGGER trg_stack_box_docs_updated_at
        BEFORE UPDATE ON stack_box_docs
        FOR EACH ROW EXECUTE FUNCTION set_updated_at()
    """)
  end

  def down do
    execute("DROP TABLE IF EXISTS stack_box_docs")
  end
end
