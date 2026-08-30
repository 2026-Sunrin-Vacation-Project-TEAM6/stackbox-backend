defmodule Stackbox.Repo.Migrations.CreateBlockReactions do
  use Ecto.Migration

  def up do
    execute("""
    CREATE TABLE block_reactions (
        id         BIGSERIAL PRIMARY KEY,
        block_id   BIGINT NOT NULL REFERENCES blocks(id) ON DELETE CASCADE,
        user_id    BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        reaction   VARCHAR(32) NOT NULL,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        UNIQUE (block_id, user_id, reaction)
    )
    """)

    execute("CREATE INDEX idx_block_reactions_block ON block_reactions (block_id)")
  end

  def down do
    execute("DROP TABLE IF EXISTS block_reactions")
  end
end
