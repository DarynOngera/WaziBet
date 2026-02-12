defmodule WaziBet.Repo.Migrations.CreateOutcomes do
  use Ecto.Migration

  def change do
    create table(:outcomes) do
      add :label, :string, null: false
      add :odds, :decimal, precision: 10, scale: 2, null: false
      add :probability, :float, null: false
      add :result, :string, null: false, default: "pending"
      add :market_id, references(:markets, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:outcomes, [:market_id])
    create constraint(:outcomes, :odds_positive, check: "odds > 0")

    create constraint(:outcomes, :probability_range,
             check: "probability >= 0 AND probability <= 1"
           )
  end
end
