defmodule WaziBet.Bets.Settlement do
  @moduledoc """
  Settlement logic for betslips and selections.
  """

  import Ecto.Query

  alias WaziBet.Accounts.User
  alias WaziBet.Bets.{Betslip, BetslipSelection, OddsCalculator}
  alias WaziBet.Repo
  alias Ecto.Multi

  @doc """
  Gets all pending betslips that have selections on a specific game.
  """
  def get_pending_betslips_for_game(game_id) do
    Repo.all(
      from b in Betslip,
        join: s in assoc(b, :selections),
        where: s.game_id == ^game_id and b.status == :pending,
        distinct: true,
        preload: [selections: [:outcome, :game]]
    )
  end

  @doc """
  Checks if all games in a betslip have finished.
  """
  def all_games_finished?(betslip) do
    Enum.all?(betslip.selections, fn s -> s.game.status == :finished end)
  end

  @doc """
  Determines the result of a betslip based on its selections.
  Returns :won, :lost, or :pending.
  """
  def get_betslip_result(betslip) do
    betslip = Repo.preload(betslip, :selections)

    cond do
      Enum.any?(betslip.selections, fn s -> s.status == :lost end) ->
        :lost

      Enum.all?(betslip.selections, fn s -> s.status == :won end) ->
        :won

      Enum.any?(betslip.selections, fn s -> s.status == :void end) and
          Enum.all?(betslip.selections, fn s -> s.status in [:won, :void] end) ->
        :won

      true ->
        :pending
    end
  end

  @doc """
  Settles a betslip and credits the user if it won.
  """
  def settle_betslip_with_credit(betslip) do
    betslip = Repo.preload(betslip, :selections)
    result = get_betslip_result(betslip)

    case result do
      :won ->
        Multi.new()
        |> Multi.update(:betslip, Betslip.status_changeset(betslip, :won))
        |> Multi.run(:credit_user, fn repo, _ ->
          user = repo.get!(User, betslip.user_id)
          # Recalculate payout excluding void selections
          active_selections = Enum.reject(betslip.selections, fn s -> s.status == :void end)

          payout =
            OddsCalculator.payout(
              betslip.stake,
              OddsCalculator.accumulator_odds(active_selections)
            )

          new_balance = Decimal.add(user.balance, payout)
          User.balance_changeset(user, %{balance: new_balance}) |> repo.update()
        end)
        |> Repo.transaction()

      :lost ->
        betslip
        |> Betslip.status_changeset(:lost)
        |> Repo.update()

      :pending ->
        {:ok, betslip}
    end
  end

  @doc """
  Refunds a betslip (when game is void/cancelled).
  """
  def refund_betslip(betslip) do
    Multi.new()
    |> Multi.update(:betslip, Betslip.status_changeset(betslip, :void))
    |> Multi.run(:refund_user, fn repo, _ ->
      user = repo.get!(User, betslip.user_id)
      new_balance = Decimal.add(user.balance, betslip.stake)
      User.balance_changeset(user, %{balance: new_balance}) |> repo.update()
    end)
    |> Repo.transaction()
  end

  @doc """
  Updates selection status when outcome is settled.
  """
  def update_selection_status(selection_id, status) do
    selection = Repo.get!(BetslipSelection, selection_id)

    selection
    |> BetslipSelection.status_changeset(status)
    |> Repo.update()
  end

  @doc """
  Gets all pending selections for a specific game and outcome.
  """
  def get_pending_selections(game_id, outcome_id) do
    Repo.all(
      from s in BetslipSelection,
        where: s.game_id == ^game_id and s.outcome_id == ^outcome_id and s.status == :pending
    )
  end
end
