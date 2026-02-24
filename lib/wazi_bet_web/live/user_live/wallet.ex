defmodule WaziBetWeb.UserLive.Wallet do
  @moduledoc """
  User wallet view showing winnings, losses, and account summary.
  Requires authentication and 'view_winnings_losses' permission.
  """

  use WaziBetWeb, :live_view

  alias WaziBet.Bets

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    summary = Bets.get_user_winnings_summary(user.id)

    {:ok,
     socket
     |> assign(:user, user)
     |> assign(:summary, summary)
     |> assign(:page_title, "My Wallet")}
  end

  def net_profit(summary) do
    Decimal.sub(summary.total_won, summary.total_lost)
  end

  def profit_color(summary) do
    net = net_profit(summary)

    cond do
      Decimal.compare(net, Decimal.new(0)) == :gt -> "text-success"
      Decimal.compare(net, Decimal.new(0)) == :lt -> "text-error"
      true -> "text-base-content"
    end
  end
end
