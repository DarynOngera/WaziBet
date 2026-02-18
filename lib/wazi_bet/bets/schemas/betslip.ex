defmodule WaziBet.Bets.Betslip do
  use Ecto.Schema
  import Ecto.Changeset

  alias WaziBet.Accounts.User
  alias WaziBet.Bets.BetslipSelection

  @status [:pending, :won, :lost, :void, :cashed_out]

  schema "betslips" do
    field :stake, :decimal
    field :total_odds, :decimal
    field :potential_payout, :decimal
    field :status, Ecto.Enum, values: @status, default: :pending
    field :cancelled_at, :utc_datetime

    belongs_to :user, User
    has_many :selections, BetslipSelection

    timestamps()
  end

  def changeset(betslip, attrs) do
    betslip
    |> cast(attrs, [:stake, :total_odds, :potential_payout, :user_id])
    |> validate_required([:stake, :total_odds, :potential_payout, :user_id])
    |> validate_stake()
    |> validate_odds()
    |> validate_payout()
    |> foreign_key_constraint(:user_id)
  end

  def status_changeset(betslip, status) when status in @status do
    change(betslip, status: status)
  end

  defp validate_stake(changeset) do
    changeset
    |> validate_number(:stake, greater_than: 0)
    |> check_constraint(:stake, name: :stake_positive)
  end

  defp validate_odds(changeset) do
    changeset
    |> validate_number(:total_odds, greater_than: 0)
    |> check_constraint(:total_odds, name: :total_odds_positive)
  end

  defp validate_payout(changeset) do
    changeset
    |> validate_number(:potential_payout, greater_than: 0)
    |> check_constraint(:potential_payout, name: :potential_payout_positive)
  end
end
