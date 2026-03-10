defmodule WaziBetWeb.Admin.AdminLive.Profits do
  @moduledoc """
  Admin profits dashboard showing financial statistics.
  Requires authentication and 'view_profits_from_losses' permission.
  """

  use WaziBetWeb, :live_view

  alias WaziBet.{Accounts, Bets}

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    current_path = "/admin/profits"

    stats = Bets.get_profit_stats()
    user_permissions = Accounts.get_user_permission_slugs(user.id)
    is_superuser = WaziBet.Can.can_slug?(user, "grant-revoke-admin-access")

    {:ok,
     socket
     |> assign(:stats, stats)
     |> assign(:user_permissions, user_permissions)
     |> assign(:is_superuser, is_superuser)
     |> assign(:current_path, current_path)
     |> assign(:summary, Bets.get_all_bets_summary())
     |> assign(:profit_stats, Bets.get_profit_stats())
     |> assign(:bet_counts, Bets.count_total_bets())
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

  def has_permission?(%WaziBet.Accounts.User{} = user, slug),
    do: WaziBet.Can.can_slug?(user, slug)

  def has_permission?(_user, _slug), do: false
end
