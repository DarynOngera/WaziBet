defmodule WaziBet.Repo.Migrations.RemoveMarketsTable do
  use Ecto.Migration

  def up do
    # First drop the foreign key constraint and market_id column from outcomes
    alter table(:outcomes) do
      remove :market_id
    end

    # Add game_id to outcomes
    alter table(:outcomes) do
      add :game_id, references(:games, on_delete: :delete_all), null: false
      add :status, :string, default: "open"
    end

    create index(:outcomes, [:game_id])

    # Drop the markets table
    drop table(:markets)
  end

  def down do
    # Recreate markets table
    create table(:markets) do
      add :game_id, references(:games, on_delete: :delete_all), null: false
      add :type, :string, null: false
      add :status, :string, default: "open"

      timestamps()
    end

    create index(:markets, [:game_id])
    create unique_index(:markets, [:game_id, :type])

    # Revert outcomes changes
    alter table(:outcomes) do
      remove :game_id
      remove :status
      add :market_id, references(:markets, on_delete: :delete_all), null: false
    end

    create index(:outcomes, [:market_id])
  end
end
