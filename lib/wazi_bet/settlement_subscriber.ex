defmodule WaziBet.SettlementSubscriber do
  @moduledoc """
  Dynamically spawned GenServer that listens for game finished events
  and coordinates settlement.
  """

  use GenServer

  alias WaziBet.Bets
  alias WaziBet.Bets.Settlement
  alias WaziBet.Workers.BetslipSettlementWorker

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, nil)
  end

  @impl true
  def init(_) do
    # Subscribe to all game events
    Phoenix.PubSub.subscribe(WaziBet.PubSub, "game:*")
    {:ok, nil}
  end

  @impl true
  def handle_info(
        {WaziBet.Simulation.GameServer, game_id,
         {:finished, %{home_score: _home_score, away_score: _away_score}}},
        state
      ) do
    IO.puts("DEBUG: SettlementSubscriber received finished event for game #{game_id}")

    # Find and process betslips that have selections on this game
    betslips = Settlement.get_pending_betslips_for_game(game_id)
    IO.inspect(betslips, label: "DEBUG: betslips for game")

    Enum.each(betslips, fn betslip ->
      # Reload betslip with all selections and games
      full_betslip = Bets.get_betslip_with_selections!(betslip.id)

      if Settlement.all_games_finished?(full_betslip) do
        IO.puts(
          "DEBUG: All games finished, inserting settlement worker for betslip #{full_betslip.id}"
        )

        %{betslip_id: full_betslip.id}
        |> BetslipSettlementWorker.new()
        |> Oban.insert()
      else
        IO.puts("DEBUG: Not all games finished yet")
      end
    end)

    {:noreply, state}
  end

  def handle_info(_, state) do
    {:noreply, state}
  end
end
