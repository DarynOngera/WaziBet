defmodule WaziBet.Simulation.ProbabilityEngine do
  @moduledoc """
  Calculates goal probabilities based on team ratings and fair odds.
  """

  alias WaziBet.Bets.OddsCalculator

  @goal_probability_multiplier 0.04

  def determine_event(fair_odds) do
    home_prob = OddsCalculator.odds_to_probability(fair_odds.home)
    draw_prob = OddsCalculator.odds_to_probability(fair_odds.draw)

    rand = :rand.uniform()

    cond do
      rand < home_prob * @goal_probability_multiplier -> :home_score
      rand < (home_prob + draw_prob) * @goal_probability_multiplier -> :away_score
      true -> :none
    end
  end
end
