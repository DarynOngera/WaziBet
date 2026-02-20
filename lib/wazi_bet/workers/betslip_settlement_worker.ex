defmodule WaziBet.Workers.BetslipSettlementWorker do
  @moduledoc """
  Oban worker to settle a betslip based on game scores and credit the user.
  """

  use Oban.Worker, queue: :settlements, max_attempts: 3

  alias WaziBet.Bets
  alias WaziBet.Bets.Settlement

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{
          "betslip_id" => betslip_id,
          "home_score" => home_score,
          "away_score" => away_score
        }
      }) do
    betslip = Bets.get_betslip_with_selections!(betslip_id)

    # Check if already settled (idempotent)
    if betslip.status != :pending do
      :ok
    else
      # Determine the winning label based on scores
      winning_label =
        cond do
          home_score > away_score -> :home
          home_score < away_score -> :away
          true -> :draw
        end

      # Update each selection status based on the outcome
      Enum.each(betslip.selections, fn selection ->
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
        {:ok, _} -> :ok
        {:error, _} = error -> error
      end
    end
  end
end
