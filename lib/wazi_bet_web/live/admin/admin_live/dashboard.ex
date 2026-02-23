defmodule WaziBetWeb.Admin.AdminLive.Dashboard do
  @moduledoc """
  Common admin dashboard accessible to all admins.
  Shows overview stats and quick links to admin functions.
  """

  use WaziBetWeb, :live_view

  alias WaziBet.{Accounts, Bets}

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    # Check if superuser (can grant/revoke admin access)
    is_superuser = Accounts.user_has_permission?(user.id, "grant-revoke-admin-access")

    # Get stats
    total_users = length(Accounts.list_users())
    stats = Bets.get_profit_stats()

    # Get user's permissions for menu
    user_permissions = Accounts.get_user_permission_slugs(user.id)

    {:ok,
     socket
     |> assign(:is_superuser, is_superuser)
     |> assign(:total_users, total_users)
     |> assign(:stats, stats)
     |> assign(:user_permissions, user_permissions)
     |> assign(:page_title, "Admin Dashboard")}
  end

  def has_permission?(permissions, slug), do: slug in permissions
end
