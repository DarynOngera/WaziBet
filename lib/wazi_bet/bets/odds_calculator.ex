defmodule WaziBet.Bets.OddsCalculator do
  @moduledoc """
  Odds calculation utilities for betting operations.

  This module handles all odds-related calculations including:
  - Probability to odds conversion
  - Odds to probability conversion
  - Fair odds calculation based on team ratings
  - Bookmaker margin application
  - Accumulator odds calculation
  - Payout calculations
  """

  alias Decimal

  def probability_to_odds(probability) when is_float(probability) or is_integer(probability) do
    if probability > 0 do
      Decimal.from_float(1.0 / probability)
    else
      raise ArgumentError, "Probability must be greater than 0"
    end
  end

  def odds_to_probability(odds) do
    odds_float = Decimal.to_float(odds)

    if odds_float > 0 do
      1.0 / odds_float
    else
      raise ArgumentError, "Odds must be greater than 0"
    end
  end

  def calculate_fair_odds(home_attack, home_defense, away_attack, away_defense)
      when is_integer(home_attack) and is_integer(home_defense) and is_integer(away_attack) and is_integer(away_defense) do
    home_performance = home_attack / away_defense 
    away_performance = away_attack / home_defense 

    # Base probabilities
    home_prob = home_performance / (home_performance + away_performance)
    away_prob = away_performance / (home_performance + away_performance)

    draw_prob = 0.25
    home_prob = home_prob * 0.75
    away_prob = away_prob * 0.75

    %{
      home: probability_to_odds(home_prob),
      draw: probability_to_odds(draw_prob),
      away: probability_to_odds(away_prob)
    }
  end

  def apply_margin(fair_odds, margin) when is_float(margin) or is_integer(margin) do
    margin_decimal = Decimal.from_float(margin)

    Enum.map(fair_odds, fn {label, odds} ->
      adjusted_odds =
        odds
        |> Decimal.mult(Decimal.sub(1, margin_decimal))
        |> Decimal.round(2)

      {label, adjusted_odds}
    end)
    |> Enum.into(%{})
  end

  def accumulator_odds(selections) when is_list(selections) do
    Enum.reduce(selections, Decimal.new(1), fn selection, acc ->
      odds = Map.get(selection, :odds) || Map.get(selection, :odds_at_placement)
      Decimal.mult(acc, odds)
    end)
  end

  def payout(stake, total_odds) do
    Decimal.mult(stake, total_odds)
  end

  def profit(stake, total_odds) do
    total_payout = payout(stake, total_odds)
    Decimal.sub(total_payout, stake)
  end

  def implied_probability_sum(odds_list) when is_list(odds_list) do
    odds_list
    |> Enum.map(&odds_to_probability/1)
    |> Enum.sum()
  end

  def validate_odds(odds) when is_binary(odds) do
    decimal_odds = Decimal.new(odds)
    validate_odds(decimal_odds)
  end

  def validate_odds(odds) when is_float(odds) do
    validate_odds(Decimal.from_float(odds))
  end

  def validate_odds(odds) when is_integer(odds) do
    validate_odds(Decimal.new(odds))
  end

  def validate_odds(%Decimal{} = odds) do
    if Decimal.compare(odds, Decimal.new(0)) == :gt do
      odds
    else
      raise ArgumentError, "Odds must be greater than 0"
    end
  end

  def format_for_display(%Decimal{} = odds) do
    odds
    |> Decimal.round(2)
    |> Decimal.to_string(:normal)
  end
end
