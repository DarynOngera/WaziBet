defmodule WaziBetWeb.Plugs.RequirePermission do
  @moduledoc """
  Plug for requiring specific permissions on routes.

  ## Usage in router

  # Single permission
  plug WaziBetWeb.Plugs.RequirePermission, "view-games"

  # Multiple permissions (user needs ANY of them)
  plug WaziBetWeb.Plugs.RequirePermission, ["view-games", "place-bets"]
  """

  use WaziBetWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  alias WaziBet.Can

  def init(permission_or_permissions) do
    permission_or_permissions
  end

  def call(conn, permission) when is_binary(permission) do
    check_permission(conn, [permission], :any)
  end

  def call(conn, permissions) when is_list(permissions) do
    check_permission(conn, permissions, :any)
  end

  defp check_permission(conn, permissions, :any) do
    user = conn.assigns.current_scope && conn.assigns.current_scope.user

    cond do
      is_nil(user) ->
        conn
        |> put_flash(:error, "You must log in to access this page.")
        |> redirect(to: ~p"/users/log-in")
        |> halt()

      Can.can_any_slug?(user, permissions) ->
        conn

      true ->
        conn
        |> put_flash(:error, "You don't have permission to access this page.")
        |> redirect(to: ~p"/")
        |> halt()
    end
  end
end
