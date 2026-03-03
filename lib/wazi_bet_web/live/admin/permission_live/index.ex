defmodule WaziBetWeb.Admin.PermissionLive.Index do
  @moduledoc """
  Admin permissions list view.
  Requires authentication and 'assign-roles' permission.
  """

  use WaziBetWeb, :live_view

  alias WaziBet.Accounts

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    current_path = "/admin/permissions"

    user_permissions = Accounts.get_user_permission_slugs(user.id)
    is_superuser = Accounts.user_has_permission?(user.id, "grant-revoke-admin-access")

    permissions = Accounts.list_permissions()

    {:ok,
     socket
     |> assign(:user_permissions, user_permissions)
     |> assign(:is_superuser, is_superuser)
     |> assign(:current_path, current_path)
     |> assign(:permissions, permissions)
     |> assign(:page_title, "Permissions")}
  end

  @impl true
  def handle_event("delete_permission", %{"id" => id}, socket) do
    permission = Accounts.get_permission!(id)

    case Accounts.delete_permission(permission) do
      {:ok, _} ->
        permissions = Accounts.list_permissions()

        {:noreply,
         socket
         |> assign(:permissions, permissions)
         |> put_flash(:info, "Permission deleted successfully")}

      {:error, :permission_in_use} ->
        {:noreply,
         socket
         |> put_flash(:error, "Cannot delete permission: it is assigned to one or more roles")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete permission")}
    end
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
end
