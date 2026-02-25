defmodule WaziBetWeb.Admin.RoleLive.Index do
  @moduledoc """
  Admin roles list view.
  Requires authentication and 'assign_roles' permission.
  """

  use WaziBetWeb, :live_view

  alias WaziBet.Accounts

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    current_path = "/admin/roles"

    user_permissions = Accounts.get_user_permission_slugs(user.id)
    is_superuser = Accounts.user_has_permission?(user.id, "grant-revoke-admin-access")

    roles = Accounts.list_roles_with_permissions()

    {:ok,
     socket
     |> assign(:user_permissions, user_permissions)
     |> assign(:is_superuser, is_superuser)
     |> assign(:current_path, current_path)
     |> assign(:roles, roles)
     |> assign(:page_title, "Roles")}
  end

  def permission_badge_color("place-bets"), do: "badge-success"
  def permission_badge_color("cancel-bets"), do: "badge-warning"
  def permission_badge_color("view-bet-history"), do: "badge-info"
  def permission_badge_color("view-winnings-losses"), do: "badge-info"
  def permission_badge_color("create-users"), do: "badge-error"
  def permission_badge_color("assign-roles"), do: "badge-error"
  def permission_badge_color("grant-revoke-admin-access"), do: "badge-error"
  def permission_badge_color("view-users"), do: "badge-error"
  def permission_badge_color("view-user-games"), do: "badge-error"
  def permission_badge_color("soft-delete-users"), do: "badge-error"
  def permission_badge_color("view-profits-from-losses"), do: "badge-error"
  def permission_badge_color("configure-games"), do: "badge-error"
  def permission_badge_color(_), do: "badge-ghost"

  def has_permission?(permissions, slug), do: slug in permissions
end
