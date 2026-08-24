defmodule Stackbox.Repo.Migrations.CreateGithubAccounts do
  use Ecto.Migration

  def up do
    execute("""
    CREATE TABLE github_accounts (
        id                     BIGSERIAL PRIMARY KEY,
        user_id                BIGINT NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
        github_user_id         VARCHAR(64) NOT NULL UNIQUE,
        github_login           VARCHAR(255) NOT NULL,
        access_token_encrypted TEXT NOT NULL,
        connected_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
    """)
  end

  def down do
    execute("DROP TABLE IF EXISTS github_accounts")
  end
end
