defmodule WaziBet.Repo.Migrations.CreateBetslipSelections do
  use Ecto.Migration

  def change do
    create table(:betslip_selections) do
      add :odds_at_placement, :decimal, precision: 10, scale: 2, null: false
      add :status, :string, null: false, default: "pending"
      add :betslip_id, references(:betslips, on_delete: :delete_all), null: false
      add :outcome_id, references(:outcomes, on_delete: :restrict), null: false
      add :game_id, references(:games, on_delete: :restrict), null: false

      timestamps()
    end

    create index(:betslip_selections, [:betslip_id])
    create index(:betslip_selections, [:outcome_id])
    create index(:betslip_selections, [:game_id])
    create unique_index(:betslip_selections, [:betslip_id, :outcome_id])
    create constraint(:betslip_selections, :odds_positive, check: "odds_at_placement > 0")
  end
end
