defmodule WaziBet.Workers.GameStartWorker do
  @moduledoc """
  Oban worker that starts a game when its scheduled time arrives.
  """
  use Oban.Worker, queue: :game_starts

  alias WaziBet.Sport
  alias WaziBet.Bets
  alias WaziBet.Simulation.GameSupervisor

  @doc """
  Schedule a game to start at the given time.
  """
  def schedule(game_id, scheduled_time) do
    %{game_id: game_id}
    |> new(scheduled_at: scheduled_time)
    |> Oban.insert!()
  end

  @impl true
  def perform(%Oban.Job{args: %{"game_id" => game_id}}) do
    IO.puts("GameStartWorker: Starting game #{game_id}")

    try do
      game = Sport.get_game_with_teams!(game_id)
      IO.puts("GameStartWorker: Game status is #{game.status}")

      # Only start if still scheduled
      if game.status == :scheduled do
        IO.puts("GameStartWorker: Transitioning game to live")

        # Transition to live
        {:ok, _} = Sport.transition_game_status(game, :live)
        IO.puts("GameStartWorker: Game transitioned to live")

        Phoenix.PubSub.broadcast( WaziBet.PubSub, "games", {__MODULE__, game_id, :started})

        # Close betting on all outcomes
        Bets.close_outcomes_for_game(game_id)
        IO.puts("GameStartWorker: Outcomes closed")

        # Start the game simulation
        GameSupervisor.start_game(game)
        IO.puts("GameStartWorker: Game simulation started")
      else
        IO.puts("GameStartWorker: Game not started - status is #{game.status}")
      end
    rescue
      e ->
        IO.puts("GameStartWorker: ERROR - #{inspect(e)}")
        reraise e, __STACKTRACE__
    end

    :ok
  end
end
