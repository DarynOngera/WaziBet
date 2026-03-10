defmodule WaziBetWeb.Admin.CategoryLive.Index do
  @moduledoc """
  Admin category management list view.
  Requires authentication and 'configure_games' permission.
  """

  use WaziBetWeb, :live_view

  alias WaziBet.{Sport, Accounts}

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    current_path = "/admin/categories"

    user_permissions = Accounts.get_user_permission_slugs(user.id)
    is_superuser = WaziBet.Can.can_slug?(user, "grant-revoke-admin-access")

    categories = Sport.list_categories()

    {:ok,
     socket
     |> assign(:user_permissions, user_permissions)
     |> assign(:is_superuser, is_superuser)
     |> assign(:current_path, current_path)
     |> assign(:show_create_category_modal, false)
     |> assign(:categories, categories)
     |> assign(:page_title, "Sports Categories")}
  end

  @impl true
  def handle_event("open_create_category_modal", _params, socket) do
    {:noreply, assign(socket, :show_create_category_modal, true)}
  end

  @impl true
  def handle_event("close_create_category_modal", _params, socket) do
    {:noreply, assign(socket, :show_create_category_modal, false)}
  end

  @impl true
  def handle_event("create_category", %{"name" => name}, socket) do
    case Sport.create_category(%{name: name}) do
      {:ok, _category} ->
        categories = Sport.list_categories()

        {:noreply,
         socket
         |> assign(:show_create_category_modal, false)
         |> assign(:categories, categories)
         |> put_flash(:info, "Category created successfully!")}

      {:error, changeset} ->
        {:noreply,
         put_flash(socket, :error, "Failed to create category: #{inspect(changeset.errors)}")}
    end
  end

  @impl true
  def handle_event("delete_category", %{"id" => id}, socket) do
    category = Sport.get_category!(String.to_integer(id))

    case Sport.delete_category(category) do
      {:ok, _} ->
        categories = Sport.list_categories()

        {:noreply,
         socket
         |> assign(:categories, categories)
         |> put_flash(:info, "Category deleted successfully!")}

      {:error, changeset} ->
        {:noreply,
         put_flash(socket, :error, "Failed to delete category: #{inspect(changeset.errors)}")}
    end
  end

  def has_permission?(%WaziBet.Accounts.User{} = user, slug),
    do: WaziBet.Can.can_slug?(user, slug)

  def has_permission?(_user, _slug), do: false
end
