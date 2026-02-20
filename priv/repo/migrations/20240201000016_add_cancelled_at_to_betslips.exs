defmodule WaziBet.Repo.Migrations.AddCancelledAtToBetslips do
  use Ecto.Migration

  def change do
    alter table(:betslips) do
      add :cancelled_at, :utc_datetime
    end
  end
end
