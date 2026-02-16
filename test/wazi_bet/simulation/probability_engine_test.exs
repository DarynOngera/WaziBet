defmodule WaziBet.Simulation.ProbabilityEngineTest do
  use ExUnit.Case, async: true

  alias WaziBet.Simulation.ProbabilityEngine

  describe "determine_event/1" do
    test "returns valid event result" do
      fair_odds = %{
        home: Decimal.new("2.0"),
        draw: Decimal.new("3.5"),
        away: Decimal.new("3.5")
      }

      result = ProbabilityEngine.determine_event(fair_odds)

      assert result in [:home_score, :away_score, :none]
    end

    test "biased odds produce more home goals" do
      # Strong home favorite
      fair_odds = %{
        home: Decimal.new("1.3"),
        draw: Decimal.new("4.5"),
        away: Decimal.new("8.0")
      }

      results =
        for _ <- 1..1000 do
          ProbabilityEngine.determine_event(fair_odds)
        end

      home_goals = Enum.count(results, &(&1 == :home_score))
      away_goals = Enum.count(results, &(&1 == :away_score))

      assert home_goals > away_goals
    end

    test "equal odds produce balanced results" do
      fair_odds = %{
        home: Decimal.new("2.5"),
        draw: Decimal.new("3.0"),
        away: Decimal.new("2.5")
      }

      results =
        for _ <- 1..1000 do
          ProbabilityEngine.determine_event(fair_odds)
        end

      home_goals = Enum.count(results, &(&1 == :home_score))
      away_goals = Enum.count(results, &(&1 == :away_score))

      # Should be reasonably close
      diff = abs(home_goals - away_goals)
      assert diff < 50
    end
  end
end
