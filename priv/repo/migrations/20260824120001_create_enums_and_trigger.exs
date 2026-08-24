defmodule Stackbox.Repo.Migrations.CreateEnumsAndTrigger do
  use Ecto.Migration

  def up do
    execute("CREATE TYPE stack_box_type AS ENUM ('folder', 'page', 'canvas', 'edgeless')")
    execute("CREATE TYPE workspace_role AS ENUM ('owner', 'admin', 'editor', 'viewer')")
    execute("CREATE TYPE doc_mode AS ENUM ('page', 'edgeless')")
    execute("CREATE TYPE block_type AS ENUM ('markdown', 'code')")

    execute("""
    CREATE OR REPLACE FUNCTION set_updated_at()
    RETURNS TRIGGER AS $$
    BEGIN
        NEW.updated_at = NOW();
        RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    """)
  end

  def down do
    execute("DROP FUNCTION IF EXISTS set_updated_at()")
    execute("DROP TYPE IF EXISTS block_type")
    execute("DROP TYPE IF EXISTS doc_mode")
    execute("DROP TYPE IF EXISTS workspace_role")
    execute("DROP TYPE IF EXISTS stack_box_type")
  end
end
