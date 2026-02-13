defmodule WaziBet.Simulation.GameState do
  @moduledoc """
  In-memory state struct for game simulation.
  """

  alias WaziBet.Bets.OddsCalculator

  @status {:scheduled, :live, :finished}

  defstruct [
    :game_id,
    :home_team,
    :away_team,
    :status,
    :home_score,
    :away_score,
    :events,
    :sync_count,
    :fair_odds,
    :next_tick_at
  ]

  def new(game) do
    fair_odds =
      OddsCalculator.calculate_fair_odds(
        game.home_team.attack_rating,
        game.home_team.defense_rating,
        game.away_team.attack_rating,
        game.away_team.defense_rating
      )

    %__MODULE__{
      game_id: game.id,
      home_team: game.home_team.name,
      away_team: game.away_team.name,
      status: elem(@status, 0),
      home_score: 0,
      away_score: 0,
      events: [],
      sync_count: 0,
      fair_odds: fair_odds,
      next_tick_at: nil
    }
  end

  def start(%__MODULE__{} = state) when elem(@status, 0) == state.status do
    now = DateTime.utc_now()
    %{state | status: elem(@status, 1), next_tick_at: now}
  end

  def start(state), do: state

  def current_minute(%__MODULE__{} = state) do
    length(state.events)
  end

  def needs_sync?(%__MODULE__{sync_count: count}) when count >= 10, do: true
  def needs_sync?(_), do: false

  def reset_sync(%__MODULE__{} = state) do
    %{state | sync_count: 0}
  end

  def unsynced_events(%__MODULE__{} = state) do
    Enum.take(state.events, state.sync_count)
  end
end
