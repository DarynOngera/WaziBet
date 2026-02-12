defmodule WaziBet.Bets.Market do
  use Ecto.Schema
  import Ecto.Changeset

  alias WaziBet.Football.Game
  alias WaziBet.Bets.Outcome

  @types [:match_result]
  @status [:open, :closed, :settled]

  schema "markets" do
    field :type, Ecto.Enum, values: @types, default: :match_result
    field :status, Ecto.Enum, values: @status, default: :open

    belongs_to :game, Game
    has_many :outcomes, Outcome

    timestamps()
  end

  def changeset(market, attrs) do
    market
    |> cast(attrs, [:type, :status, :game_id])
    |> validate_required([:type, :game_id])
    |> validate_inclusion(:type, @types)
    |> validate_inclusion(:status, @status)
    |> foreign_key_constraint(:game_id)
    |> unique_constraint([:game_id, :type],
      name: :markets_game_id_type_index,
      message: "already exists for this game")
  end

  def status_changeset(market, status) when status in @status do
    change(market, status: status)
  end
end
