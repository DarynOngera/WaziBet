defmodule WaziBet.Repo.Migrations.AddUserProfileFields do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :first_name, :string
      add :last_name, :string
      add :msisdn, :string
    end

    create unique_index(:users, [:msisdn])
  end
end
