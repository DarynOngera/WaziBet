defmodule WaziBet.Bets.BetslipSelection do
  use Ecto.Schema
  import Ecto.Changeset

  alias WaziBet.Bets.{Betslip, Outcome}
  alias WaziBet.Sport.Game

  @status [:pending, :won, :lost, :void]

  schema "betslip_selections" do
    field :odds_at_placement, :decimal
    field :status, Ecto.Enum, values: @status, default: :pending

    belongs_to :betslip, Betslip
    belongs_to :outcome, Outcome
    belongs_to :game, Game

    timestamps()
  end

  def changeset(selection, attrs) do
    selection
    |> cast(attrs, [:odds_at_placement, :betslip_id, :outcome_id, :game_id])
    |> validate_required([:odds_at_placement, :betslip_id, :outcome_id, :game_id])
    |> validate_odds()
    |> foreign_key_constraint(:betslip_id)
    |> foreign_key_constraint(:outcome_id)
    |> foreign_key_constraint(:game_id)
    |> unique_constraint([:betslip_id, :outcome_id],
      name: :betslip_selections_betslip_id_outcome_id_index,
      message: "already exists in this betslip"
    )
  end

  def status_changeset(selection, status) when status in @status do
    change(selection, status: status)
  end

  defp validate_odds(changeset) do
    changeset
    |> validate_number(:odds_at_placement, greater_than: 0)
    |> check_constraint(:odds_at_placement, name: :odds_positive)
  end
end
