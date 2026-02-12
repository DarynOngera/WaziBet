defmodule WaziBet.Repo.Migrations.CreateBetslips do
  use Ecto.Migration

  def change do
    create table(:betslips) do
      add :stake, :decimal, precision: 20, scale: 2, null: false
      add :total_odds, :decimal, precision: 10, scale: 2, null: false
      add :potential_payout, :decimal, precision: 20, scale: 2, null: false
      add :status, :string, null: false, default: "pending"
      add :user_id, references(:users, on_delete: :restrict), null: false

      timestamps()
    end

    create index(:betslips, [:user_id])
    create index(:betslips, [:user_id, :status])
    create constraint(:betslips, :stake_positive, check: "stake > 0")
    create constraint(:betslips, :total_odds_positive, check: "total_odds > 0")
    create constraint(:betslips, :potential_payout_positive, check: "potential_payout > 0")
  end
end
