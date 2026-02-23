defmodule WaziBetWeb.Admin.CategoryLive.Index do
  @moduledoc """
  Admin category management list view.
  Requires authentication and 'configure_games' permission.
  """

  use WaziBetWeb, :live_view

  alias WaziBet.Sport

  @impl true
  def mount(_params, _session, socket) do
    categories = Sport.list_categories()

    {:ok,
     socket
     |> assign(:categories, categories)
     |> assign(:page_title, "Sports Categories")}
  end

  @impl true
  def handle_event("create_category", %{"name" => name}, socket) do
    case Sport.create_category(%{name: name}) do
      {:ok, _category} ->
        categories = Sport.list_categories()

        {:noreply,
         socket
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
end
