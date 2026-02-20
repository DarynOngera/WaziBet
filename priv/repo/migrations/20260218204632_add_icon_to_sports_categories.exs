defmodule WaziBet.Repo.Migrations.AddIconToSportsCategories do
  use Ecto.Migration

  def change do
    alter table(:sports_categories) do
      add :icon, :string, default: "hero-trophy"
    end
  end
end
