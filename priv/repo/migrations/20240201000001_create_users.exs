defmodule WaziBet.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :email, :string, null: false
      add :balance, :decimal, precision: 20, scale: 2, default: 0
      add :hashed_password, :string, null: false

      timestamps()
    end

    create unique_index(:users, [:email])
    create constraint(:users, :balance_must_be_non_negative, check: "balance >= 0")
  end
end
