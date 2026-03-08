defmodule WaziBetWeb.Admin.RoleLive.Assign do
  @moduledoc """
  Admin assign/revoke roles to users view.
  Requires authentication and 'assign_roles' permission.
  Grant/revoke admin access requires 'grant_revoke_admin_access' permission.
  """

  use WaziBetWeb, :live_view

  alias WaziBet.Accounts
  @page_size 10

  @impl true
  def mount(params, _session, socket) do
    user = socket.assigns.current_scope.user
    current_path = "/admin/roles/assign"
    page = parse_page(params)

    user_permissions = Accounts.get_user_permission_slugs(user.id)
    is_superuser = Accounts.user_has_permission?(user.id, "grant-revoke-admin-access")

    users = Accounts.list_users(page: page, page_size: @page_size)
    total_count = Accounts.count_users()
    total_pages = ceil(total_count / @page_size)
    roles = Accounts.list_roles()
    can_manage_admin = Accounts.user_has_permission?(user.id, "grant-revoke-admin-access")

    {:ok,
     socket
     |> assign(:user_permissions, user_permissions)
     |> assign(:is_superuser, is_superuser)
     |> assign(:current_path, current_path)
     |> assign(:users, users)
     |> assign(:roles, roles)
     |> assign(:current_page, page)
     |> assign(:total_pages, total_pages)
     |> assign(:total_count, total_count)
     |> assign(:can_manage_admin, can_manage_admin)
     |> assign(:selected_user, nil)
     |> assign(:user_roles, [])
     |> assign(:page_title, "Assign Roles")}
  end

  @impl true
  def handle_params(params, _url, socket) do
    page = parse_page(params)
    users = Accounts.list_users(page: page, page_size: @page_size)
    total_count = Accounts.count_users()
    total_pages = ceil(total_count / @page_size)

    {:noreply,
     socket
     |> assign(:users, users)
     |> assign(:current_page, page)
     |> assign(:total_pages, total_pages)
     |> assign(:total_count, total_count)}
  end

  @impl true
  def handle_event("select_user", %{"user_id" => user_id}, socket) do
    user_id = String.to_integer(user_id)
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

  def pagination_start(%{current_page: _page, total_count: total}) when total == 0, do: 0

  def pagination_start(%{current_page: page, total_count: _total}),
    do: (page - 1) * @page_size + 1

  def pagination_end(%{current_page: page, total_count: total}) do
    min(page * @page_size, total)
  end

  def page_size, do: @page_size

  defp parse_page(params) do
    params
    |> Map.get("page", "1")
    |> String.to_integer()
    |> max(1)
  end

  def has_permission?(permissions, slug), do: slug in permissions
end
