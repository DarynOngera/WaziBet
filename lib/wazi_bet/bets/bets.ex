defmodule WaziBet.Bets do

  import Ecto.Query

  alias WaziBet.Accounts.User
  alias WaziBet.Bets.{Market, Outcome, Betslip, BetslipSelection}
  alias WaziBet.Repo
  alias Ecto.Multi

  # Markets

  def create_market(game_id, type \\ :match_result) do
    %Market{}
    |> Market.changeset(%{game_id: game_id, type: type})
    |> Repo.insert()
  end

  def get_market!(id) do
    Repo.get!(Market, id)
  end

  def get_market_by_game_and_type(game_id, type) do
    Repo.get_by(Market, game_id: game_id, type: type)
  end

  def close_market(market) do
    market
    |> Market.status_changeset(:closed)
    |> Repo.update()
  end

  def settle_market(market, winning_outcome_label) do
    Multi.new()
    |> Multi.update(:market, Market.status_changeset(market, :settled))
    |> Multi.run(:settle_outcomes, fn repo, _ ->
      outcomes = repo.all(from o in Outcome, where: o.market_id == ^market.id)

      Enum.each(outcomes, fn outcome ->
        result =
          if outcome.label == winning_outcome_label do
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

  # Outcomes

  def create_outcomes_for_market(market_id, probabilities) do
    labels = [:home, :draw, :away]

    Enum.zip(labels, probabilities)
    |> Enum.map(fn {label, probability} ->
      odds = Decimal.from_float(1.0 / probability)

      %Outcome{}
      |> Outcome.changeset(%{
        market_id: market_id,
        label: label,
        odds: odds,
        probability: probability
      })
      |> Repo.insert()
    end)
  end

  def update_odds(outcome_id, new_odds, new_probability) do
    outcome = Repo.get!(Outcome, outcome_id)

    outcome
    |> Outcome.odds_changeset(%{odds: new_odds, probability: new_probability})
    |> Repo.update()
  end

  def get_outcome!(id) do
    Repo.get!(Outcome, id)
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
    Enum.reduce(selections, Decimal.new(1), fn sel, acc ->
      Decimal.mult(acc, sel.odds)
    end)
  end

  def calculate_potential_payout(stake, total_odds) do
    Decimal.mult(stake, total_odds)
  end
end
