defmodule WaziBet.Repo.Migrations.CreateSportsCategories do
  use Ecto.Migration

  def change do
    create table(:sports_categories) do
      add :name, :string, null: false

      timestamps()
    end
  end
end
