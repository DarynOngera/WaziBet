defmodule WaziBetWeb.Admin.UserLive.Index do
  @moduledoc """
  Admin user list view.
  Requires authentication and 'view_users' permission.
  """

  use WaziBetWeb, :live_view

  alias WaziBet.Accounts

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    current_path = "/admin/users"

    users = Accounts.list_users()
    user_permissions = Accounts.get_user_permission_slugs(user.id)
    is_superuser = Accounts.user_has_permission?(user.id, "grant-revoke-admin-access")

    {:ok,
     socket
     |> assign(:users, users)
     |> assign(:user_permissions, user_permissions)
     |> assign(:is_superuser, is_superuser)
     |> assign(:current_path, current_path)
     |> assign(:page_title, "Users")}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    users =
      if String.trim(query) == "" do
        Accounts.list_users()
      else
        search_users(query)
      end

    {:noreply, assign(socket, :users, users)}
  end

  defp search_users(query) do
    query = String.downcase(query)

    Accounts.list_users()
    |> Enum.filter(fn user ->
      String.downcase(user.email) =~ query ||
        String.downcase(user.first_name || "") =~ query ||
        String.downcase(user.last_name || "") =~ query
    end)
  end

  def role_badge_color("admin"), do: "badge-error"
  def role_badge_color("user"), do: "badge-info"
  def role_badge_color(_), do: "badge-ghost"

  def user_roles(user) do
    user.roles |> Enum.map(& &1.slug)
  end

  def has_permission?(permissions, slug), do: slug in permissions
end
