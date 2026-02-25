defmodule WaziBetWeb.Admin.AdminLive.Dashboard do
  @moduledoc """
  Common admin dashboard accessible to all admins.
  Shows overview stats and quick links to admin functions.
  """

  use WaziBetWeb, :live_view

  alias WaziBet.{Accounts, Bets, Sport}

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    current_path = "/admin/dashboard"

    is_superuser = Accounts.user_has_permission?(user.id, "grant-revoke-admin-access")

    total_users = length(Accounts.list_users())
    stats = Bets.get_profit_stats()
    game_counts = Sport.count_games_by_status()
    bet_counts = Bets.count_total_bets()

    user_permissions = Accounts.get_user_permission_slugs(user.id)

    {:ok,
     socket
     |> assign(:is_superuser, is_superuser)
     |> assign(:total_users, total_users)
     |> assign(:stats, stats)
     |> assign(:game_counts, game_counts)
     |> assign(:bet_counts, bet_counts)
     |> assign(:user_permissions, user_permissions)
     |> assign(:current_path, current_path)
     |> assign(:page_title, "Admin Dashboard")}
  end

  def has_permission?(permissions, slug), do: slug in permissions
end
