defmodule WaziBetWeb.BetslipLive.New do
  @moduledoc """
  Create a new betslip with selections.
  Requires authentication and 'place_bets' permission.
  Supports game_id query param for pre-selection from game detail page.
  """

  use WaziBetWeb, :live_view

  alias WaziBet.{Bets, Sport}
  alias WaziBet.Bets.{OddsCalculator, Betslip}

  @impl true
  def mount(params, _session, socket) do
    user = socket.assigns.current_scope.user

    # Load selections from pending betslip in DB
    pending = Bets.get_or_create_pending_betslip(user.id)
    selections = pending.selections || []

    # Filter out any selections from games that are no longer available
    selections =
      Enum.filter(selections, fn s ->
        case Sport.get_game(s.game_id) do
          nil -> false
          game -> game.status == :scheduled
        end
      end)

    # If we filtered some, persist the cleaned list
    if length(selections) != length(pending.selections || []) do
      Bets.update_pending_selections(user.id, selections)
    end

    games = load_available_games()

    {:ok,
     socket
     |> assign(:user, user)
     |> assign(:selections, selections)
     |> assign(:games, games)
     |> assign(:stake, Decimal.to_string(pending.stake))
     |> assign(:page_title, "Place Bet")
     |> assign(:changeset, Betslip.changeset(%Betslip{}, %{}))}
  end

  @impl true
  def handle_event("add_selection", %{"game_id" => game_id, "outcome_id" => outcome_id}, socket) do
    game_id = String.to_integer(game_id)
    outcome_id = String.to_integer(outcome_id)

    # If this exact outcome is already selected, do nothing
    if Enum.any?(socket.assigns.selections, fn s -> s.outcome_id == outcome_id end) do
      {:noreply, socket}
    else
      game = Sport.get_game_with_teams!(game_id)
      outcome = Bets.get_outcome!(outcome_id)

      selection = %{
        outcome_id: outcome.id,
        game_id: game.id,
        game_name: "#{game.home_team.name} vs #{game.away_team.name}",
        label: outcome.label,
        odds: outcome.odds
      }

      # Remove any existing selection from this game, then add the new one
      new_selections =
        socket.assigns.selections
        |> Enum.reject(fn s -> s.game_id == game_id end)
        |> Kernel.++([selection])

      # Persist to DB
      user = socket.assigns.user
      Bets.update_pending_selections(user.id, new_selections)

      {:noreply,
       socket
       |> assign(:selections, new_selections)
       |> assign(:changeset, Betslip.changeset(%Betslip{}, %{}))}
    end
  end

  @impl true
  def handle_event("remove_selection", %{"index" => index}, socket) do
    {_, new_selections} = List.pop_at(socket.assigns.selections, String.to_integer(index))

    # Persist to DB
    user = socket.assigns.user
    Bets.update_pending_selections(user.id, new_selections)

    {:noreply,
     socket
     |> assign(:selections, new_selections)
     |> assign(:changeset, Betslip.changeset(%Betslip{}, %{}))}
  end

  @impl true
  def handle_event("update_stake", %{"stake" => stake}, socket) do
    # Persist stake to DB
    user = socket.assigns.user
    stake_decimal = Decimal.new(stake)
    Bets.update_pending_stake(user.id, stake_decimal)

    {:noreply, assign(socket, :stake, stake)}
  end

  @impl true
  def handle_event("place_bet", _params, socket) do
    user = socket.assigns.user
    selections = socket.assigns.selections
    stake = Decimal.new(socket.assigns.stake)

    if Enum.empty?(selections) do
      {:noreply,
       socket
       |> put_flash(:error, "Please select at least one outcome")
       |> assign(:changeset, Betslip.changeset(%Betslip{}, %{}))}
    else
      case Bets.place_betslip(user, selections, stake) do
        {:ok, _result} ->
          # Clear pending betslip after successful placement
          Bets.clear_pending_selections(user.id)

          {:noreply,
           socket
           |> put_flash(:info, "Bet placed successfully!")
           |> push_navigate(to: ~p"/betslip")}

        {:error, :validate_balance, :insufficient_balance, _} ->
          {:noreply,
           socket
           |> put_flash(:error, "Insufficient balance to place this bet")
           |> assign(:changeset, Betslip.changeset(%Betslip{}, %{}))}

        {:error, :game_not_scheduled, _, _} ->
          {:noreply,
           socket
           |> put_flash(:error, "One of the games is no longer available for betting")
           |> assign(:changeset, Betslip.changeset(%Betslip{}, %{}))}

        {:error, :game_already_started, _, _} ->
          {:noreply,
           socket
           |> put_flash(:error, "One of the games has already started")
           |> assign(:changeset, Betslip.changeset(%Betslip{}, %{}))}

        {:error, :betting_closed, _, _} ->
          {:noreply,
           socket
           |> put_flash(:error, "Betting closes 5 minutes before a game starts")
           |> assign(:changeset, Betslip.changeset(%Betslip{}, %{}))}

        {:error, _, _, _} ->
          {:noreply,
           socket
           |> put_flash(:error, "Failed to place bet. Please try again.")
           |> assign(:changeset, Betslip.changeset(%Betslip{}, %{}))}
      end
    end
  end

  defp load_available_games do
    Sport.list_games(status: :scheduled)
    |> Enum.map(fn game ->
      game = Sport.get_game_with_teams!(game.id)
      outcomes = Bets.get_outcomes_for_game(game.id)
      Map.put(game, :outcomes, outcomes)
    end)
  end

  def calculate_total_odds([]), do: Decimal.new(1)

  def calculate_total_odds(selections) do
    OddsCalculator.accumulator_odds(selections)
  end

  def calculate_potential_payout(selections, stake) do
    total_odds = calculate_total_odds(selections)
    OddsCalculator.payout(Decimal.new(stake), total_odds)
  end
end
