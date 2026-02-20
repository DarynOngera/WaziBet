defmodule WaziBet.Repo.Migrations.CreatePermissions do
  use Ecto.Migration

  def change do
    create table(:permissions) do
      add :permission, :string, null: false
      add :slug, :string, null: false

      timestamps()
    end

    create unique_index(:permissions, [:slug])
  end
end
