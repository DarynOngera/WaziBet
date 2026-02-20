defmodule WaziBet.Repo.Migrations.CreateTeams do
  use Ecto.Migration

  def change do
    create table(:teams) do
      add :name, :string, null: false
      add :attack_rating, :integer, default: 50
      add :defense_rating, :integer, default: 50
      add :category_id, references(:sports_categories, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:teams, [:category_id])
    create unique_index(:teams, [:category_id, :name])

    create constraint(:teams, :attack_rating_range,
             check: "attack_rating >= 0 AND attack_rating <= 100"
           )

    create constraint(:teams, :defense_rating_range,
             check: "defense_rating >= 0 AND defense_rating <= 100"
           )
  end
end
