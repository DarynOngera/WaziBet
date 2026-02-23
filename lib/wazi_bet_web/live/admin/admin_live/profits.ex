defmodule WaziBetWeb.Admin.AdminLive.Profits do
  @moduledoc """
  Admin profits dashboard showing financial statistics.
  Requires authentication and 'view_profits_from_losses' permission.
  """

  use WaziBetWeb, :live_view

  alias WaziBet.Bets

  @impl true
  def mount(_params, _session, socket) do
    stats = Bets.get_profit_stats()

    {:ok,
     socket
     |> assign(:stats, stats)
     |> assign(:page_title, "Profits Dashboard")}
  end

  def profit_color(amount) do
    cond do
      Decimal.compare(amount, Decimal.new(0)) == :gt -> "text-success"
      Decimal.compare(amount, Decimal.new(0)) == :lt -> "text-error"
      true -> "text-base-content"
    end
  end

  def profit_bg(amount) do
    cond do
      Decimal.compare(amount, Decimal.new(0)) == :gt -> "bg-success/10"
      Decimal.compare(amount, Decimal.new(0)) == :lt -> "bg-error/10"
      true -> "bg-base-200"
    end
  end
end
