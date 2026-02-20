defmodule WaziBet.Repo.Migrations.CreateRoles do
  use Ecto.Migration

  def change do
    create table(:roles) do
      add :role, :string, null: false
      add :slug, :string, null: false

      timestamps()
    end

    create unique_index(:roles, [:slug])
  end
end
