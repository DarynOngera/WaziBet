defmodule WaziBet.Workers.BetslipSettlementWorker do
  @moduledoc """
  Oban worker to settle a betslip based on game scores and credit the user.
  """

  use Oban.Worker, queue: :settlements, max_attempts: 3

  require Logger

  alias WaziBet.Bets
  alias WaziBet.Bets.Settlement
  alias WaziBet.Sport

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{
          "betslip_id" => betslip_id
        }
      }) do
    Logger.debug("BetslipSettlementWorker starting for betslip_id=#{betslip_id}")
    betslip = Bets.get_betslip_with_selections!(betslip_id)

    # Check if already settled (idempotent)
    if betslip.status != :pending do
      Logger.debug(
        "BetslipSettlementWorker no-op; betslip_id=#{betslip_id} status=#{betslip.status}"
      )

      :ok
    else
      # Check if all games are finished
      unless Settlement.all_games_finished?(betslip) do
        Logger.info(
          "BetslipSettlementWorker snoozing; betslip_id=#{betslip_id} not all games finished"
        )

        {:snooze, 30}
      else
        Logger.debug("BetslipSettlementWorker settling selections; betslip_id=#{betslip_id}")

        # Update each selection status based on each game's actual result
        Enum.each(betslip.selections, fn selection ->
          # Reload the game to get its current status and score
          game = Sport.get_game!(selection.game_id)

          # Determine winning label from actual game scores
          winning_label =
            cond do
              game.home_score > game.away_score -> :home
              game.home_score < game.away_score -> :away
              true -> :draw
            end

          selection_status =
            if selection.outcome.label == winning_label do
              :won
            else
              :lost
            end

          Settlement.update_selection_status(selection.id, selection_status)
        end)

        # Reload betslip with updated selections and settle
        betslip = Bets.get_betslip_with_selections!(betslip_id)

        case Settlement.settle_betslip_with_credit(betslip) do
          {:ok, _} ->
            Logger.info(
              "BetslipSettlementWorker settled betslip_id=#{betslip_id} status=#{betslip.status}"
            )

            :ok

          {:error, _} = error ->
            Logger.error(
              "BetslipSettlementWorker failed for betslip_id=#{betslip_id}: #{inspect(error)}"
            )

            error
        end
      end
    end
  end
end
