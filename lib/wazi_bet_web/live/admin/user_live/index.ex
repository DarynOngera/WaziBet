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
    is_superuser = WaziBet.Can.can_slug?(user, "grant-revoke-admin-access")

    page = Map.get(params, "page", "1") |> String.to_integer() |> max(1)
    query = Map.get(params, "query", "") || ""

    {users, total_count} = list_paginated_users(page, query)
    total_pages = ceil(total_count / @page_size)
    roles = Accounts.list_roles()
    changeset = Accounts.User.registration_changeset(%Accounts.User{}, %{}, validate_email: false)

    {:ok,
     socket
     |> assign(:users, users)
     |> assign(:roles, roles)
     |> assign(:show_create_user_modal, false)
     |> assign(:create_user_form, to_form(changeset, as: :user))
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

  @impl true
  def handle_event("open_create_user_modal", _params, socket) do
    changeset = Accounts.User.registration_changeset(%Accounts.User{}, %{}, validate_email: false)

    {:noreply,
     socket
     |> assign(:show_create_user_modal, true)
     |> assign(:create_user_form, to_form(changeset, as: :user))}
  end

  @impl true
  def handle_event("close_create_user_modal", _params, socket) do
    {:noreply, assign(socket, :show_create_user_modal, false)}
  end

  @impl true
  def handle_event("validate_create_user", %{"user" => user_params}, socket) do
    changeset =
      %Accounts.User{}
      |> Accounts.User.registration_changeset(user_params, validate_email: false)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :create_user_form, to_form(changeset, as: :user))}
  end

  @impl true
  def handle_event("save_create_user", %{"user" => user_params}, socket) do
    role_id = user_params["role_id"]
    user_params_clean = Map.drop(user_params, ["role_id"])

    case Accounts.create_user(user_params_clean) do
      {:ok, user} ->
        if role_id && role_id != "" do
          Accounts.assign_role_to_user(user.id, String.to_integer(role_id))
        end

        {users, total_count} =
          list_paginated_users(socket.assigns.current_page, socket.assigns.search_query)

        total_pages = ceil(total_count / @page_size)

        changeset =
          Accounts.User.registration_changeset(%Accounts.User{}, %{}, validate_email: false)

        {:noreply,
         socket
         |> assign(:users, users)
         |> assign(:total_pages, total_pages)
         |> assign(:total_count, total_count)
         |> assign(:show_create_user_modal, false)
         |> assign(:create_user_form, to_form(changeset, as: :user))
         |> put_flash(:info, "User created successfully")}

      {:error, changeset} ->
        {:noreply, assign(socket, :create_user_form, to_form(changeset, as: :user))}
    end
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

  def has_permission?(%WaziBet.Accounts.User{} = user, slug),
    do: WaziBet.Can.can_slug?(user, slug)

  def has_permission?(_user, _slug), do: false

  def pagination_start(%{current_page: _page, total_count: total}) when total == 0, do: 0

  def pagination_start(%{current_page: page, total_count: _total}),
    do: (page - 1) * @page_size + 1

  def pagination_end(%{current_page: page, total_count: total}) do
    min(page * @page_size, total)
  end

  def page_size, do: @page_size
end
