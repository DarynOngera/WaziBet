defmodule WaziBetWeb.Admin.GameLive.New do
  @moduledoc """
  Admin create new game view.
  Requires authentication and 'configure_games' permission.
  """

  use WaziBetWeb, :live_view

  alias WaziBet.Sport
  alias WaziBet.Bets
  alias WaziBet.Bets.OddsCalculator
  alias WaziBet.Workers.GameStartWorker
  alias WaziBet.Simulation.GameSupervisor
  alias WaziBetWeb.Timezone

  @impl true
  def mount(_params, _session, socket) do
    categories = Sport.list_categories()
    changeset = Sport.Game.create_changeset(%Sport.Game{}, %{})

    {:ok,
     socket
     |> assign(:categories, categories)
     |> assign(:teams, [])
     |> assign(:selected_category, nil)
     |> assign(:home_team, nil)
     |> assign(:away_team, nil)
     |> assign(:calculated_odds, nil)
     |> assign(:start_immediately, false)
     |> assign(:changeset, changeset)
     |> assign(:page_title, "New Game")}
  end

  @impl true
  def handle_event("category_changed", %{"game" => %{"category_id" => category_id}}, socket) do
    category_id = String.to_integer(category_id)
    teams = Sport.list_teams(category_id)

    {:noreply,
     socket
     |> assign(:teams, teams)
     |> assign(:selected_category, category_id)
     |> assign(:home_team, nil)
     |> assign(:away_team, nil)
     |> assign(:calculated_odds, nil)}
  end

  @impl true
  def handle_event("team_selected", %{"_target" => target, "game" => game_params}, socket) do
    # Determine which field changed from _target: ["game", "home_team_id"] or ["game", "away_team_id"]
    field =
      case target do
        ["game", "home_team_id"] -> "home"
        ["game", "away_team_id"] -> "away"
        _ -> nil
      end

    team_id =
      case field do
        "home" -> game_params["home_team_id"]
        "away" -> game_params["away_team_id"]
        _ -> nil
      end

    team =
      if team_id && team_id != "",
        do: Enum.find(socket.assigns.teams, fn t -> t.id == String.to_integer(team_id) end),
        else: nil

    socket =
      case field do
        "home" -> assign(socket, :home_team, team)
        "away" -> assign(socket, :away_team, team)
        _ -> socket
      end

    # Calculate odds preview if both teams are selected
    socket =
      if socket.assigns.home_team && socket.assigns.away_team do
        odds = calculate_odds_preview(socket.assigns.home_team, socket.assigns.away_team)
        assign(socket, :calculated_odds, odds)
      else
        assign(socket, :calculated_odds, nil)
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_immediate_start", _params, socket) do
    {:noreply, assign(socket, :start_immediately, !socket.assigns.start_immediately)}
  end

  @impl true
  def handle_event("validate", %{"game" => game_params}, socket) do
    changeset =
      %Sport.Game{}
      |> Sport.Game.create_changeset(game_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  @impl true
  def handle_event("save", %{"game" => game_params}, socket) do
    home_team_id = socket.assigns.home_team.id
    away_team_id = socket.assigns.away_team.id
    start_immediately = game_params["start_immediately"] == "on"

    if home_team_id == away_team_id do
      changeset =
        %Sport.Game{}
        |> Sport.Game.create_changeset(game_params)
        |> Ecto.Changeset.add_error(:away_team_id, "must be different from home team")

      {:noreply, assign(socket, :changeset, changeset)}
    else
      # Set starts_at based on immediate start or scheduled time
      # Convert from local (UTC+3) to UTC for storage
      starts_at =
        if start_immediately do
          DateTime.utc_now()
        else
          # datetime-local input format: "2026-02-23T12:37" (no seconds)
          # Append ":00" to make it valid ISO8601
          datetime_str = game_params["starts_at"] <> ":00"

          datetime_str
          |> NaiveDateTime.from_iso8601!()
          |> Timezone.to_utc()
        end

      attrs = %{
        category_id: socket.assigns.selected_category,
        home_team_id: home_team_id,
        away_team_id: away_team_id,
        starts_at: starts_at
      }

      case Sport.create_game_with_calculated_odds(attrs) do
        {:ok, game} ->
          # If start immediately is checked, start the game now
          if start_immediately do
            Sport.transition_game_status(game, :live)
            Bets.close_outcomes_for_game(game.id)
            game_with_teams = Sport.get_game_with_teams!(game.id)
            GameSupervisor.start_game(game_with_teams)
          else
            # Schedule the Oban job to start the game at the scheduled time
            GameStartWorker.schedule(game.id, game.starts_at)
          end

          message =
            if start_immediately do
              "Game created and started successfully! Simulation is now running."
            else
              "Game scheduled successfully. It will start automatically at the scheduled time."
            end

          {:noreply,
           socket
           |> put_flash(:info, message)
           |> push_navigate(to: ~p"/admin/games")}

        {:error, changeset} ->
          {:noreply, assign(socket, :changeset, changeset)}
      end
    end
  end

  defp calculate_odds_preview(home_team, away_team) do
    fair_odds =
      OddsCalculator.calculate_fair_odds(
        home_team.attack_rating,
        home_team.defense_rating,
        away_team.attack_rating,
        away_team.defense_rating
      )

    # Apply bookmaker margin
    OddsCalculator.apply_margin(fair_odds, 0.05)
  end
end
