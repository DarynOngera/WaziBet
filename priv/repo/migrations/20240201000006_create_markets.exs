defmodule WaziBet.Repo.Migrations.CreateMarkets do
  use Ecto.Migration

  def change do
    create table(:markets) do
      add :type, :string, null: false, default: "match_result"
      add :status, :string, null: false, default: "open"
      add :game_id, references(:games, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:markets, [:game_id])
    create unique_index(:markets, [:game_id, :type])
  end
end
