defmodule WaziBetWeb.AdminRedirectController do
  @moduledoc """
  Redirects /admin to the admin dashboard.
  """

  use WaziBetWeb, :controller

  alias WaziBet.Can

  def index(conn, _params) do
    user = conn.assigns.current_scope.user

    # Check if user has any admin permissions
    admin_permissions = [
      "view-users",
      "view-profits-from-losses",
      "configure-games",
      "assign-roles"
    ]

    has_admin_access =
      Can.can_any_slug?(user, admin_permissions)

    if has_admin_access do
      redirect(conn, to: ~p"/admin/dashboard")
    else
      conn
      |> put_flash(:error, "You don't have access to the admin area")
      |> redirect(to: ~p"/")
    end
  end
end
