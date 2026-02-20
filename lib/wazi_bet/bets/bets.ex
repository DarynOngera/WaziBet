defmodule WaziBet.Bets do
  @moduledoc """
  Betting outcomes and betslips.
  """

  import Ecto.Query

  alias WaziBet.Accounts.User
  alias WaziBet.Bets.{Outcome, Betslip, BetslipSelection, OddsCalculator}
  alias WaziBet.Repo
  alias Ecto.Multi

  # Outcomes

  def create_outcomes_for_game(game_id, probabilities) do
    labels = [:home, :draw, :away]

    Enum.zip(labels, probabilities)
    |> Enum.map(fn {label, probability} ->
      odds = OddsCalculator.probability_to_odds(probability)

      %Outcome{}
      |> Outcome.changeset(%{
        game_id: game_id,
        label: label,
        odds: odds,
        probability: probability,
        status: :open
      })
      |> Repo.insert()
    end)
  end

  def get_outcome!(id) do
    Repo.get!(Outcome, id)
  end

  def get_outcomes_for_game(game_id) do
    Repo.all(
      from o in Outcome,
        where: o.game_id == ^game_id,
        order_by: [asc: o.label]
    )
  end

  def update_odds(outcome_id, new_odds, new_probability) do
    outcome = Repo.get!(Outcome, outcome_id)

    outcome
    |> Outcome.odds_changeset(%{odds: new_odds, probability: new_probability})
    |> Repo.update()
  end

  def close_outcomes_for_game(game_id) do
    Repo.update_all(
      from(o in Outcome, where: o.game_id == ^game_id),
      set: [status: :closed]
    )
  end

  def settle_outcomes_for_game(game_id, winning_label) do
    Multi.new()
    |> Multi.run(:outcomes, fn repo, _ ->
      outcomes = repo.all(from o in Outcome, where: o.game_id == ^game_id)

      Enum.each(outcomes, fn outcome ->
        result =
          if outcome.label == winning_label do
            :won
          else
            :lost
          end

        outcome
        |> Outcome.settlement_changeset(result)
        |> repo.update()
      end)

      {:ok, outcomes}
    end)
    |> Repo.transaction()
  end

  # Betslips

  def place_betslip(user, selections, stake) do
    total_odds = calculate_accumulator_odds(selections)
    potential_payout = calculate_potential_payout(stake, total_odds)

    Multi.new()
    |> Multi.run(:lock_user, fn repo, _ ->
      user = from(u in User, where: u.id == ^user.id, lock: "FOR UPDATE") |> repo.one()
      {:ok, user}
    end)
    |> Multi.run(:validate_balance, fn _, %{lock_user: user} ->
      if Decimal.compare(user.balance, stake) >= 0 do
        {:ok, user}
      else
        {:error, :insufficient_balance}
      end
    end)
    |> Multi.update(:deduct_balance, fn %{lock_user: user} ->
      new_balance = Decimal.sub(user.balance, stake)
      User.balance_changeset(user, %{balance: new_balance})
    end)
    |> Multi.insert(:betslip, fn %{deduct_balance: user} ->
      Betslip.changeset(%Betslip{}, %{
        user_id: user.id,
        stake: stake,
        total_odds: total_odds,
        potential_payout: potential_payout
      })
    end)
    |> Multi.insert_all(:selections, BetslipSelection, fn %{betslip: betslip} ->
      Enum.map(selections, fn %{outcome_id: outcome_id, game_id: game_id, odds: odds} ->
        %{
          betslip_id: betslip.id,
          outcome_id: outcome_id,
          game_id: game_id,
          odds_at_placement: odds,
          status: :pending,
          inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
          updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
        }
      end)
    end)
    |> Repo.transaction()
  end

  def get_betslip!(id) do
    Repo.get!(Betslip, id)
  end

  def get_betslip_with_selections!(id) do
    Repo.get!(Betslip, id)
    |> Repo.preload(selections: [:outcome, :game])
  end

  def list_user_betslips(user_id) do
    Repo.all(
      from b in Betslip,
        where: b.user_id == ^user_id,
        order_by: [desc: b.inserted_at]
    )
  end

  def get_active_betslips do
    Repo.all(from b in Betslip, where: b.status == :pending)
  end

  def settle_betslip(betslip) do
    betslip = Repo.preload(betslip, :selections)

    selections = betslip.selections

    cond do
      Enum.any?(selections, fn s -> s.status == :lost end) ->
        betslip
        |> Betslip.status_changeset(:lost)
        |> Repo.update()

      Enum.all?(selections, fn s -> s.status == :won end) ->
        Multi.new()
        |> Multi.update(:betslip, Betslip.status_changeset(betslip, :won))
        |> Multi.run(:credit_user, fn repo, _ ->
          user = repo.get!(User, betslip.user_id)
          new_balance = Decimal.add(user.balance, betslip.potential_payout)
          User.balance_changeset(user, %{balance: new_balance}) |> repo.update()
        end)
        |> Repo.transaction()

      Enum.any?(selections, fn s -> s.status == :void end) and
          Enum.all?(selections, fn s -> s.status in [:won, :void] end) ->
        betslip
        |> Betslip.status_changeset(:won)
        |> Repo.update()

      true ->
        {:ok, betslip}
    end
  end

  # Utilities

  def calculate_accumulator_odds(selections) do
    OddsCalculator.accumulator_odds(selections)
  end

  def calculate_potential_payout(stake, total_odds) do
    OddsCalculator.payout(stake, total_odds)
  end

  def get_user_winnings_summary(user_id) do
    betslips = list_user_betslips(user_id)

    %{
      total_wagered: calculate_total_wagered(betslips),
      total_won: calculate_total_won(betslips),
      total_lost: calculate_total_lost(betslips),
      bets_won: count_bets_by_status(betslips, :won),
      bets_lost: count_bets_by_status(betslips, :lost),
      bets_pending: count_bets_by_status(betslips, :pending),
      total_bets: length(betslips)
    }
  end

  def calculate_profits_from_losses do
    from(b in Betslip,
      where: b.status == :lost,
      select: sum(b.stake)
    )
    |> Repo.one() || Decimal.new(0)
  end

  def calculate_total_payouts do
    from(b in Betslip,
      where: b.status == :won,
      select: sum(b.potential_payout)
    )
    |> Repo.one() || Decimal.new(0)
  end

  def get_profit_stats do
    total_stakes_lost = calculate_profits_from_losses()
    total_payouts = calculate_total_payouts()

    %{
      total_stakes_lost: total_stakes_lost,
      total_payouts: total_payouts,
      net_profit: Decimal.sub(total_stakes_lost, total_payouts),
      total_bets_lost: count_all_by_status(:lost),
      total_bets_won: count_all_by_status(:won)
    }
  end

  defp calculate_total_wagered(betslips) do
    betslips
    |> Enum.reduce(Decimal.new(0), fn b, acc -> Decimal.add(acc, b.stake) end)
  end

  defp calculate_total_won(betslips) do
    betslips
    |> Enum.filter(fn b -> b.status == :won end)
    |> Enum.reduce(Decimal.new(0), fn b, acc -> Decimal.add(acc, b.potential_payout) end)
  end

  defp calculate_total_lost(betslips) do
    betslips
    |> Enum.filter(fn b -> b.status == :lost end)
    |> Enum.reduce(Decimal.new(0), fn b, acc -> Decimal.add(acc, b.stake) end)
  end

  defp count_bets_by_status(betslips, status) do
    Enum.count(betslips, fn b -> b.status == status end)
  end

  defp count_all_by_status(status) do
    from(b in Betslip, where: b.status == ^status, select: count(b.id))
    |> Repo.one()
  end
end
