defmodule WaziBet.SettlementSubscriber do
  @moduledoc """
  Dynamically spawned GenServer that listens for game finished events
  and coordinates settlement.
  """

  use GenServer

  require Logger

  alias WaziBet.Bets
  alias WaziBet.Bets.Settlement
  alias WaziBet.Workers.BetslipSettlementWorker

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, nil)
  end

  @impl true
  def init(_) do
    # Subscribe to finished games
    Phoenix.PubSub.subscribe(WaziBet.PubSub, "game:finished")
    {:ok, nil}
  end

  @impl true
  def handle_info(
        {WaziBet.Simulation.GameServer, game_id,
         {:finished, %{home_score: _home_score, away_score: _away_score}}},
        state
      ) do
    Logger.debug("SettlementSubscriber received finished event for game #{game_id}")

    # Find and process betslips that have selections on this game
    betslips = Settlement.get_pending_betslips_for_game(game_id)

    Logger.debug(
      "SettlementSubscriber found #{length(betslips)} pending betslips for game #{game_id}"
    )

    Enum.each(betslips, fn betslip ->
      # Reload betslip with all selections and games
      full_betslip = Bets.get_betslip_with_selections!(betslip.id)

      if Settlement.all_games_finished?(full_betslip) do
        Logger.debug(
          "All games finished, inserting settlement worker for betslip #{full_betslip.id}"
        )

        job =
          %{betslip_id: full_betslip.id}
          |> BetslipSettlementWorker.new()

        case Oban.insert(job) do
          {:ok, _job} ->
            :ok

          {:error, changeset} ->
            Logger.error(
              "Failed to insert BetslipSettlementWorker for betslip #{full_betslip.id}: #{inspect(changeset)}"
            )
        end
      else
        Logger.debug("Not all games finished yet for betslip #{full_betslip.id}")
      end
    end)

    {:noreply, state}
  end

  def handle_info(_, state) do
    {:noreply, state}
  end
end
