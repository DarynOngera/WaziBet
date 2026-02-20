defmodule WaziBet.Bets.Outcome do
  use Ecto.Schema
  import Ecto.Changeset

  alias WaziBet.Bets.BetslipSelection
  alias WaziBet.Sport.Game

  @labels [:home, :draw, :away]
  @results [:pending, :won, :lost, :void]
  @status [:open, :closed, :settled]

  schema "outcomes" do
    field :label, Ecto.Enum, values: @labels
    field :odds, :decimal
    field :probability, :float
    field :result, Ecto.Enum, values: @results, default: :pending
    field :status, Ecto.Enum, values: @status, default: :open

    belongs_to :game, Game
    has_many :betslip_selections, BetslipSelection

    timestamps()
  end

  def changeset(outcome, attrs) do
    outcome
    |> cast(attrs, [:label, :odds, :probability, :game_id, :status])
    |> validate_required([:label, :odds, :probability, :game_id])
    |> validate_inclusion(:label, @labels)
    |> validate_odds()
    |> validate_probability()
    |> foreign_key_constraint(:game_id)
  end

  def odds_changeset(outcome, attrs) do
    outcome
    |> cast(attrs, [:odds, :probability])
    |> validate_required([:odds, :probability])
    |> validate_odds()
    |> validate_probability()
  end

  def settlement_changeset(outcome, result) when result in @results do
    change(outcome, result: result, status: :settled)
  end

  def status_changeset(outcome, status) when status in @status do
    change(outcome, status: status)
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
