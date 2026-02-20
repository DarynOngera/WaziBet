defmodule WaziBet.SettlementSubscriber do
  @moduledoc """
  Dynamically spawned GenServer that listens for game finished events
  and coordinates settlement.
  """

  use GenServer

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
         {:finished, %{home_score: home_score, away_score: away_score}}},
        state
      ) do
    # Find and process betslips
    betslips = Settlement.get_pending_betslips_for_game(game_id)

    Enum.each(betslips, fn betslip ->
      if Settlement.all_games_finished?(betslip) do
        %{betslip_id: betslip.id, home_score: home_score, away_score: away_score}
        |> BetslipSettlementWorker.new()
        |> Oban.insert()
      end
    end)

    {:noreply, state}
  end

  def handle_info(_, state) do
    {:noreply, state}
  end
end
