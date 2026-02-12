defmodule WaziBet.Repo.Migrations.CreateGames do
  use Ecto.Migration

  def change do
    create table(:games) do
      add :status, :string, null: false, default: "scheduled"
      add :minute, :integer, default: 0
      add :home_score, :integer, default: 0
      add :away_score, :integer, default: 0
      add :starts_at, :utc_datetime, null: false
      add :league_id, references(:leagues, on_delete: :restrict), null: false
      add :home_team_id, references(:teams, on_delete: :restrict), null: false
      add :away_team_id, references(:teams, on_delete: :restrict), null: false

      timestamps()
    end

    create index(:games, [:league_id])
    create index(:games, [:home_team_id])
    create index(:games, [:away_team_id])
    create index(:games, [:status])
    create index(:games, [:starts_at])
    create constraint(:games, :teams_must_differ, check: "home_team_id != away_team_id")
    create constraint(:games, :minute_range, check: "minute >= 0 AND minute <= 90")
    create constraint(:games, :scores_non_negative, check: "home_score >= 0 AND away_score >= 0")
  end
end
