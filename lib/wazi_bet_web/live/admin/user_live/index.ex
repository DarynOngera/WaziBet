defmodule WaziBetWeb.Admin.UserLive.Index do
  @moduledoc """
  Admin user list view.
  Requires authentication and 'view_users' permission.
  """

  use WaziBetWeb, :live_view

  alias WaziBet.Accounts

  @page_size 10

  @impl true
  def mount(params, _session, socket) do
    user = socket.assigns.current_scope.user
    current_path = "/admin/users"

    user_permissions = Accounts.get_user_permission_slugs(user.id)
    is_superuser = Accounts.user_has_permission?(user.id, "grant-revoke-admin-access")

    page = Map.get(params, "page", "1") |> String.to_integer() |> max(1)
    query = Map.get(params, "query", "") || ""

    {users, total_count} = list_paginated_users(page, query)
    total_pages = ceil(total_count / @page_size)

    {:ok,
     socket
     |> assign(:users, users)
     |> assign(:user_permissions, user_permissions)
     |> assign(:is_superuser, is_superuser)
     |> assign(:current_path, current_path)
     |> assign(:page_title, "Users")
     |> assign(:current_page, page)
     |> assign(:total_pages, total_pages)
     |> assign(:total_count, total_count)
     |> assign(:search_query, query)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    page = Map.get(params, "page", "1") |> String.to_integer() |> max(1)
    query = Map.get(params, "query", "") || ""

    {users, total_count} = list_paginated_users(page, query)
    total_pages = ceil(total_count / @page_size)

    {:noreply,
     socket
     |> assign(:users, users)
     |> assign(:current_page, page)
     |> assign(:total_pages, total_pages)
     |> assign(:total_count, total_count)
     |> assign(:search_query, query)}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    {users, total_count} = list_paginated_users(1, query)
    total_pages = ceil(total_count / @page_size)

    {:noreply,
     socket
     |> assign(:users, users)
     |> assign(:current_page, 1)
     |> assign(:total_pages, total_pages)
     |> assign(:total_count, total_count)
     |> assign(:search_query, query)
     |> push_patch(to: "/admin/users?page=1&query=#{URI.encode(query)}")}
  end

  defp list_paginated_users(page, query) when query == "" or is_nil(query) do
    users = Accounts.list_users(page: page, page_size: @page_size)
    total_count = Accounts.count_users()
    {users, total_count}
  end

  defp list_paginated_users(page, query) do
    filtered_users = search_users(query)
    total_count = length(filtered_users)

    paginated_users =
      filtered_users
      |> Enum.drop((page - 1) * @page_size)
      |> Enum.take(@page_size)

    {paginated_users, total_count}
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

  def pagination_start(%{current_page: _page, total_count: total}) when total == 0, do: 0

  def pagination_start(%{current_page: page, total_count: _total}),
    do: (page - 1) * @page_size + 1

  def pagination_end(%{current_page: page, total_count: total}) do
    min(page * @page_size, total)
  end

  def page_size, do: @page_size
end
