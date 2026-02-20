defmodule WaziBet.Repo.Migrations.AddAuthFieldsToUsers do
  use Ecto.Migration

  def up do
    # Add citext extension for case-insensitive email
    execute "CREATE EXTENSION IF NOT EXISTS citext", ""

    # Add authentication fields to existing users table
    alter table(:users) do
      add :confirmed_at, :utc_datetime
      add :authenticated_at, :utc_datetime
    end

    # Ensure email has unique constraint with citext
    # First check if unique index exists, if not create it
    execute """
    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM pg_indexes 
        WHERE indexname = 'users_email_index'
      ) THEN
        CREATE UNIQUE INDEX users_email_index ON users USING btree (email);
      END IF;
    END $$;
    """

    # Create users_tokens table
    create table(:users_tokens) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string
      add :authenticated_at, :utc_datetime

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:users_tokens, [:user_id])
    create unique_index(:users_tokens, [:context, :token])
  end

  def down do
    drop table(:users_tokens)

    alter table(:users) do
      remove :confirmed_at
      remove :authenticated_at
    end

    execute "DROP EXTENSION IF EXISTS citext", ""
  end
end
