defmodule WaziBet.Bets.PendingBetslip do
  use Ecto.Schema
  import Ecto.Changeset

  schema "pending_betslips" do
    field :stake, :decimal
    field :selections, {:array, :map}
    field :user_id, :integer

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(pending_betslip, attrs) do
    pending_betslip
    |> cast(attrs, [:user_id, :stake, :selections])
    |> validate_required([:user_id, :stake, :selections])
    |> validate_number(:stake, greater_than_or_equal_to: 0)
  end
end
