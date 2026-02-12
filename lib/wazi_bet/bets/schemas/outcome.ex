defmodule WaziBet.Bets.Outcome do
  use Ecto.Schema
  import Ecto.Changeset

  alias WaziBet.Bets.{Market, BetslipSelection}

  @labels [:home, :draw, :away]
  @results [:pending, :won, :lost, :void]

  schema "outcomes" do
    field :label, Ecto.Enum, values: @labels
    field :odds, :decimal
    field :probability, :float
    field :result, Ecto.Enum, values: @results, default: :pending

    belongs_to :market, Market
    has_many :betslip_selections, BetslipSelection

    timestamps()
  end

  def changeset(outcome, attrs) do
    outcome
    |> cast(attrs, [:label, :odds, :probability, :market_id])
    |> validate_required([:label, :odds, :probability, :market_id])
    |> validate_inclusion(:label, @labels)
    |> validate_odds()
    |> validate_probability()
    |> foreign_key_constraint(:market_id)
  end

  def odds_changeset(outcome, attrs) do
    outcome
    |> cast(attrs, [:odds, :probability])
    |> validate_required([:odds, :probability])
    |> validate_odds()
    |> validate_probability()
  end

  def settlement_changeset(outcome, result) when result in @results do
    change(outcome, result: result)
  end

  defp validate_odds(changeset) do
    changeset
    |> validate_number(:odds, greater_than: 0)
    |> check_constraint(:odds, name: :odds_positive)
  end

  defp validate_probability(changeset) do
    changeset
    |> validate_number(:probability, greater_than_or_equal_to: 0, less_than_or_equal_to: 1)
    |> check_constraint(:probability, name: :probability_range)
  end
end
