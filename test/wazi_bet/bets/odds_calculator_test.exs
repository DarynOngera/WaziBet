defmodule WaziBet.Bets.OddsCalculatorTest do
  use ExUnit.Case, async: true

  alias WaziBet.Bets.OddsCalculator
  alias Decimal

  describe "probability_to_odds/1" do
    test "converts probability to decimal odds" do
      assert Decimal.compare(OddsCalculator.probability_to_odds(0.5), Decimal.new("2.0")) == :eq
    end

    test "raises on zero or negative probability" do
      assert_raise ArgumentError, fn ->
        OddsCalculator.probability_to_odds(0)
      end
    end
  end

  describe "odds_to_probability/1" do
    test "converts decimal odds to probability" do
      assert OddsCalculator.odds_to_probability(Decimal.new("2.0")) == 0.5
    end

    test "raises on zero or negative odds" do
      assert_raise ArgumentError, fn ->
        OddsCalculator.odds_to_probability(Decimal.new("0"))
      end
    end
  end

  describe "accumulator_odds/1" do
    test "calculates accumulator odds from selections" do
      selections = [
        %{odds: Decimal.new("2.0")},
        %{odds: Decimal.new("1.5")}
      ]

      result = OddsCalculator.accumulator_odds(selections)
      assert Decimal.compare(result, Decimal.new("3.0")) == :eq
    end

    test "works with odds_at_placement field" do
      selections = [
        %{odds_at_placement: Decimal.new("2.5")},
        %{odds_at_placement: Decimal.new("2.0")}
      ]

      result = OddsCalculator.accumulator_odds(selections)
      assert Decimal.compare(result, Decimal.new("5.0")) == :eq
    end

    test "returns 1 for empty list" do
      assert Decimal.compare(OddsCalculator.accumulator_odds([]), Decimal.new("1")) == :eq
    end
  end

  describe "payout/2" do
    test "calculates total payout" do
      stake = Decimal.new("10.0")
      odds = Decimal.new("2.5")

      result = OddsCalculator.payout(stake, odds)
      assert Decimal.compare(result, Decimal.new("25.0")) == :eq
    end
  end

  describe "profit/2" do
    test "calculates profit from winning bet" do
      stake = Decimal.new("10.0")
      odds = Decimal.new("2.5")

      result = OddsCalculator.profit(stake, odds)
      assert Decimal.compare(result, Decimal.new("15.0")) == :eq
    end
  end


  describe "format_for_display/1" do
    test "formats odds with 2 decimal places" do
      assert OddsCalculator.format_for_display(Decimal.new("2")) == "2.00"
      assert OddsCalculator.format_for_display(Decimal.new("2.5")) == "2.50"
      assert OddsCalculator.format_for_display(Decimal.new("1.333")) == "1.33"
    end
  end

  describe "calculate_fair_odds/2" do
    test "calculates fair odds based on team ratings" do
      result = OddsCalculator.calculate_fair_odds(75, 60, 45, 65)

      assert Decimal.compare(result.home, Decimal.new("1")) == :gt
      assert Decimal.compare(result.draw, Decimal.new("1")) == :gt
      assert Decimal.compare(result.away, Decimal.new("1")) == :gt
    end
  end

  describe "apply_margin/2" do
    test "applies bookmaker margin to odds" do
      fair_odds = %{
        home: Decimal.new("2.0"),
        draw: Decimal.new("3.0"),
        away: Decimal.new("4.0")
      }

      result = OddsCalculator.apply_margin(fair_odds, 0.02)

      assert Decimal.compare(result.home, Decimal.new("2.0")) == :lt
      assert Decimal.compare(result.draw, Decimal.new("3.0")) == :lt
      assert Decimal.compare(result.away, Decimal.new("4.0")) == :lt
    end
  end

  describe "implied_probability_sum/1" do
    test "calculates sum of implied probabilities" do
      odds = [Decimal.new("2.0"), Decimal.new("2.0")]
      assert OddsCalculator.implied_probability_sum(odds) == 1.0
    end

    test "detects arbitrage opportunity" do
      odds = [Decimal.new("2.2"), Decimal.new("2.2")]
      sum = OddsCalculator.implied_probability_sum(odds)
      assert sum < 1.0
    end
  end
end
