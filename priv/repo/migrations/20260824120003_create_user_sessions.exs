defmodule Stackbox.Repo.Migrations.CreateUserSessions do
  use Ecto.Migration

  def up do
    execute("""
    CREATE TABLE user_sessions (
        id         BIGSERIAL PRIMARY KEY,
        user_id    BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        token_hash VARCHAR(255) NOT NULL UNIQUE,
        expires_at TIMESTAMPTZ NOT NULL,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
    """)

    execute("CREATE INDEX idx_user_sessions_user ON user_sessions (user_id)")
    execute("CREATE INDEX idx_user_sessions_expires ON user_sessions (expires_at)")
  end

  def down do
    execute("DROP TABLE IF EXISTS user_sessions")
  end
end
