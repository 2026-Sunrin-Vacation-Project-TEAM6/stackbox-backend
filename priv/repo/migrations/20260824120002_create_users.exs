defmodule Stackbox.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def up do
    execute("""
    CREATE TABLE users (
        id            BIGSERIAL PRIMARY KEY,
        email         VARCHAR(255) NOT NULL UNIQUE,
        password_hash VARCHAR(255),
        name          VARCHAR(100) NOT NULL,
        avatar_url    VARCHAR(512),
        is_active     BOOLEAN NOT NULL DEFAULT TRUE,
        created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
    """)

    execute("CREATE INDEX idx_users_email ON users (email)")

    execute("""
    CREATE TRIGGER trg_users_updated_at
        BEFORE UPDATE ON users
        FOR EACH ROW EXECUTE FUNCTION set_updated_at()
    """)
  end

  def down do
    execute("DROP TABLE IF EXISTS users")
  end
end
