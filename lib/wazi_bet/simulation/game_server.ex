defmodule WaziBet.Simulation.GameServer do
  @moduledoc """
  GenServer that manages a single game simulation.
  """

  use GenServer

  alias WaziBet.Sport
  alias WaziBet.Simulation.{GameState, TickEngine}

  @tick_interval 1000

  # Client API

  def start_link(game) do
    GenServer.start_link(__MODULE__, game, name: via_tuple(game.id))
  end

  def via_tuple(game_id) do
    {:via, Registry, {WaziBet.GameRegistry, game_id}}
  end

  # Server Callbacks

  @impl true
  def init(game) do
    game_state = GameState.new(game) |> GameState.start()
    schedule_tick()
    {:ok, %{game_id: game.id, state: game_state}}
  end

  @impl true
  def handle_info(:tick, %{state: state} = data) do
    case TickEngine.tick(state) do
      {:ok, new_state, event} ->
        # Persist state to database on each tick
        persist_game_state(data.game_id, new_state)

        # Broadcast full state to avoid DB queries in UI
        broadcast_data = %{
          minute: length(new_state.events),
          result: event.result,
          home_score: new_state.home_score,
          away_score: new_state.away_score,
          home_team: new_state.home_team,
          away_team: new_state.away_team
        }

        broadcast(data.game_id, broadcast_data)

        schedule_tick()
        {:noreply, %{data | state: new_state}}

      {:finished, new_state} ->
        # Persist final state
        persist_game_state(data.game_id, new_state)
        # Mark game as finished
        game = Sport.get_game!(data.game_id)
        Sport.transition_game_status(game, :finished)

        # Broadcast finished event
        broadcast(
          data.game_id,
          {:finished, %{home_score: new_state.home_score, away_score: new_state.away_score}}
        )

        {:stop, :normal, %{data | state: new_state}}
    end
  end

  defp schedule_tick do
    Process.send_after(self(), :tick, @tick_interval)
  end

  defp broadcast(game_id, event) do
    Phoenix.PubSub.broadcast(WaziBet.PubSub, "game:#{game_id}", {__MODULE__, game_id, event})
  end

  defp persist_game_state(game_id, state) do
    game = Sport.get_game!(game_id)

    attrs = %{
      minute: length(state.events),
      home_score: state.home_score,
      away_score: state.away_score
    }

    Sport.update_game_state(game, attrs)
  end
end
