defmodule WaziBet.Repo.Migrations.CreateLeagues do
  use Ecto.Migration

  def change do
    create table(:leagues) do
      add :name, :string, null: false
      add :country, :string, null: false
      add :season, :string, null: false

      timestamps()
    end
  end
end
