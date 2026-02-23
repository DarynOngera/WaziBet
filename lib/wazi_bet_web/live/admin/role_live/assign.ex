defmodule WaziBetWeb.Admin.RoleLive.Assign do
  @moduledoc """
  Admin assign/revoke roles to users view.
  Requires authentication and 'assign_roles' permission.
  Grant/revoke admin access requires 'grant_revoke_admin_access' permission.
  """

  use WaziBetWeb, :live_view

  alias WaziBet.Accounts

  @impl true
  def mount(_params, _session, socket) do
    users = Accounts.list_users()
    roles = Accounts.list_roles()
    current_user = socket.assigns.current_scope.user
    can_manage_admin = Accounts.user_has_permission?(current_user.id, "grant-revoke-admin-access")

    {:ok,
     socket
     |> assign(:users, users)
     |> assign(:roles, roles)
     |> assign(:can_manage_admin, can_manage_admin)
     |> assign(:selected_user, nil)
     |> assign(:user_roles, [])
     |> assign(:page_title, "Assign Roles")}
  end

  @impl true
  def handle_event("select_user", %{"user_id" => user_id}, socket) do
    user_id = String.to_integer(user_id)
    user = Enum.find(socket.assigns.users, fn u -> u.id == user_id end)
    user = Accounts.get_user_with_roles!(user_id)

    user_role_ids = Enum.map(user.roles, & &1.id)

    {:noreply,
     socket
     |> assign(:selected_user, user)
     |> assign(:user_roles, user_role_ids)}
  end

  @impl true
  def handle_event("toggle_role", %{"role_id" => role_id}, socket) do
    role_id = String.to_integer(role_id)
    user = socket.assigns.selected_user
    role = Enum.find(socket.assigns.roles, fn r -> r.id == role_id end)

    if role.slug == "admin" and not socket.assigns.can_manage_admin do
      {:noreply,
       socket
       |> put_flash(:error, "You don't have permission to manage admin access")}
    else
      if role_id in socket.assigns.user_roles do
        Accounts.remove_role_from_user(user.id, role_id)

        {:noreply,
         socket
         |> assign(:user_roles, List.delete(socket.assigns.user_roles, role_id))
         |> put_flash(:info, "Role removed successfully")}
      else
        Accounts.assign_role_to_user(user.id, role_id)

        {:noreply,
         socket
         |> assign(:user_roles, [role_id | socket.assigns.user_roles])
         |> put_flash(:info, "Role assigned successfully")}
      end
    end
  end
end
