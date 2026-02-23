defmodule WaziBetWeb.Admin.TeamLive.Index do
  @moduledoc """
  Admin team management list view.
  Requires authentication and 'configure_games' permission.
  """

  use WaziBetWeb, :live_view

  alias WaziBet.Sport

  @impl true
  def mount(_params, _session, socket) do
    teams = Sport.list_teams()
    categories = Sport.list_categories()

    {:ok,
     socket
     |> assign(:teams, teams)
     |> assign(:categories, categories)
     |> assign(:page_title, "Teams")}
  end

  @impl true
  def handle_event("create_team", %{"team" => team_params}, socket) do
    case Sport.create_team(team_params) do
      {:ok, _team} ->
        teams = Sport.list_teams()

        {:noreply,
         socket |> assign(:teams, teams) |> put_flash(:info, "Team created successfully!")}

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
        teams = Sport.list_teams()

        {:noreply,
         socket |> assign(:teams, teams) |> put_flash(:info, "Team deleted successfully!")}

      {:error, changeset} ->
        {:noreply,
         put_flash(socket, :error, "Failed to delete team: #{inspect(changeset.errors)}")}
    end
  end
end
