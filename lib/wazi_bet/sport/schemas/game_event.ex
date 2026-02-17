defmodule WaziBet.Sport.GameEvent do
  use Ecto.Schema
  import Ecto.Changeset

  alias WaziBet.Sport.Game

  @results [:home_score, :away_score, :none]

  schema "game_events" do
    field :minute, :integer
    field :result, Ecto.Enum, values: @results

    belongs_to :game, Game

    timestamps(updated_at: false)
  end

  def changeset(game_event, attrs) do
    game_event
    |> cast(attrs, [:minute, :result, :game_id])
    |> validate_required([:minute, :result, :game_id])
    |> validate_inclusion(:result, @results)
    |> validate_number(:minute, greater_than_or_equal_to: 0, less_than_or_equal_to: 90)
    |> foreign_key_constraint(:game_id)
  end
end
