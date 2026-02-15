defmodule WaziBet.Simulation.GameServer do
  @moduledoc """
  GenServer that manages a single game simulation.
  """

  use GenServer

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
        broadcast(data.game_id, event)
        schedule_tick()
        {:noreply, %{data | state: new_state}}

      {:finished, new_state} ->
        broadcast(data.game_id, :finished)
        {:noreply, %{data | state: new_state}}
    end
  end

  defp schedule_tick do
    Process.send_after(self(), :tick, @tick_interval)
  end

  defp broadcast(game_id, event) do
    Phoenix.PubSub.broadcast(WaziBet.PubSub, "game:#{game_id}", {__MODULE__, game_id, event})
  end
end
