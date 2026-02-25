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
    is_superuser = Accounts.user_has_permission?(user.id, "grant-revoke-admin-access")

    {:ok,
     socket
     |> assign(:stats, stats)
     |> assign(:user_permissions, user_permissions)
     |> assign(:is_superuser, is_superuser)
     |> assign(:current_path, current_path)
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

  def has_permission?(permissions, slug), do: slug in permissions
end
