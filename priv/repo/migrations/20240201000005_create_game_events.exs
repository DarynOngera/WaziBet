defmodule WaziBet.Repo.Migrations.CreateGameEvents do
  use Ecto.Migration

  def change do
    create table(:game_events) do
      add :minute, :integer, null: false
      add :result, :string, null: false
      add :game_id, references(:games, on_delete: :delete_all), null: false

      timestamps(updated_at: false)
    end

    create index(:game_events, [:game_id])
    create index(:game_events, [:game_id, :minute])
  end
end
