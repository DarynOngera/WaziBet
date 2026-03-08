defmodule WaziBetWeb.Admin.TeamLive.Index do
  @moduledoc """
  Admin team management list view.
  Requires authentication and 'configure_games' permission.
  """

  use WaziBetWeb, :live_view

  alias WaziBet.{Sport, Accounts}

  @page_size 10

  @impl true
  def mount(params, _session, socket) do
    user = socket.assigns.current_scope.user
    current_path = "/admin/teams"

    user_permissions = Accounts.get_user_permission_slugs(user.id)
    is_superuser = Accounts.user_has_permission?(user.id, "grant-revoke-admin-access")

    page = Map.get(params, "page", "1") |> String.to_integer() |> max(1)

    teams = Sport.list_teams(nil, page: page, page_size: @page_size)
    categories = Sport.list_categories()

    total_teams = Sport.count_teams()
    total_pages = ceil(total_teams / @page_size)

    {:ok,
     socket
     |> assign(:user_permissions, user_permissions)
     |> assign(:is_superuser, is_superuser)
     |> assign(:current_path, current_path)
     |> assign(:show_create_team_modal, false)
     |> assign(:teams, teams)
     |> assign(:categories, categories)
     |> assign(:page_title, "Teams")
     |> assign(:current_page, page)
     |> assign(:total_pages, total_pages)
     |> assign(:total_count, total_teams)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    page = Map.get(params, "page", "1") |> String.to_integer() |> max(1)
    teams = Sport.list_teams(nil, page: page, page_size: @page_size)
    total_teams = Sport.count_teams()
    total_pages = ceil(total_teams / @page_size)

    {:noreply,
     socket
     |> assign(:teams, teams)
     |> assign(:current_page, page)
     |> assign(:total_pages, total_pages)
     |> assign(:total_count, total_teams)}
  end

  @impl true
  def handle_event("open_create_team_modal", _params, socket) do
    {:noreply, assign(socket, :show_create_team_modal, true)}
  end

  @impl true
  def handle_event("close_create_team_modal", _params, socket) do
    {:noreply, assign(socket, :show_create_team_modal, false)}
  end

  @impl true
  def handle_event("create_team", %{"team" => team_params}, socket) do
    case Sport.create_team(team_params) do
      {:ok, _team} ->
        page = socket.assigns.current_page
        teams = Sport.list_teams(nil, page: page, page_size: @page_size)
        total_teams = Sport.count_teams()
        total_pages = ceil(total_teams / @page_size)

        {:noreply,
         socket
         |> assign(:show_create_team_modal, false)
         |> assign(:teams, teams)
         |> assign(:total_pages, total_pages)
         |> assign(:total_count, total_teams)
         |> put_flash(:info, "Team created successfully!")}

      {:error, changeset} ->
        {:noreply,
         put_flash(socket, :error, "Failed to create team: #{inspect(changeset.errors)}")}
    end
  end

  @impl true
  def handle_event("delete_team", %{"id" => id}, socket) do
    team = Sport.get_team!(String.to_integer(id))

    case Sport.delete_team(team) do
      {:ok, _} ->
        page = socket.assigns.current_page
        teams = Sport.list_teams(nil, page: page, page_size: @page_size)
        total_teams = Sport.count_teams()
        total_pages = ceil(total_teams / @page_size)

        {:noreply,
         socket
         |> assign(:teams, teams)
         |> assign(:total_pages, total_pages)
         |> assign(:total_count, total_teams)
         |> put_flash(:info, "Team deleted successfully!")}

      {:error, changeset} ->
        {:noreply,
         put_flash(socket, :error, "Failed to delete team: #{inspect(changeset.errors)}")}
    end
  end

  def has_permission?(permissions, slug), do: slug in permissions

  def pagination_start(%{current_page: _page, total_count: total}) when total == 0, do: 0

  def pagination_start(%{current_page: page, total_count: _total}),
    do: (page - 1) * @page_size + 1

  def pagination_end(%{current_page: page, total_count: total}) do
    end_val = page * @page_size
    min(end_val, total)
  end

  def page_size, do: @page_size
end
