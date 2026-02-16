defmodule WaziBet.Simulation.TickEngine do
  @moduledoc """
  Processes game ticks and updates game state.
  """

  alias WaziBet.Simulation.GameState
  alias WaziBet.Simulation.ProbabilityEngine

  @tick_interval_ms 1000 
  @game_duration 45

  def tick(%GameState{status: :live} = state) do
    current_minute = length(state.events)

    if current_minute >= @game_duration do
      {:finished, %{state | status: :finished}}
    else
      minute = current_minute + 1
      result = ProbabilityEngine.determine_event(state.fair_odds)

      state =
        case result do
          :home_score -> %{state | home_score: state.home_score + 1}
          :away_score -> %{state | away_score: state.away_score + 1}
          :none -> state
        end

      event = %{minute: minute, result: result}

      state = %{
        state
        | events: [event | state.events],
          sync_count: state.sync_count + 1,
          next_tick_at: DateTime.add(state.next_tick_at, @tick_interval_ms, :millisecond)
      }

      {:ok, state, event}
    end
  end

  def tick(_state), do: {:error, :not_live}
end
