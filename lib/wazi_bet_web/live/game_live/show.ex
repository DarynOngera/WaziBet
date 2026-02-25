defmodule WaziBetWeb.GameLive.Show do
  @moduledoc """
  Public game detail page with live scoreboard and odds.
  Accessible to both guests and authenticated users.
  """

  use WaziBetWeb, :live_view

  alias WaziBet.Sport
  alias WaziBet.Bets
  alias WaziBet.Accounts
  alias WaziBetWeb.GameLive.Components
  alias WaziBetWeb.Presence

  @impl true
  def mount(%{"id" => game_id}, _session, socket) do
    game_id = String.to_integer(game_id)
    game = Sport.get_game_with_teams!(game_id)
    outcomes = Bets.get_outcomes_for_game(game_id)
    game = Map.put(game, :outcomes, outcomes)

    # Check if user has admin permissions
    is_admin =
      if socket.assigns[:current_scope] && socket.assigns.current_scope.user do
        user = socket.assigns.current_scope.user
        Accounts.user_has_permission?(user.id, "configure-games")
      else
        false
      end

    if connected?(socket) do
      subscribe_to_game(game_id)
      # Track presence for this game
      Presence.track(self(), presence_topic(game_id), socket.id, %{
        user_email: socket.assigns[:current_scope] && socket.assigns.current_scope.user.email,
        joined_at: DateTime.utc_now(),
        game_events: []
      })

      # Schedule periodic refresh as fallback
      schedule_refresh(game_id)
    end

    # Get initial presence count and events
    presence = Presence.list(presence_topic(game_id))
    viewer_count = length(Map.keys(presence))
    events = get_game_events_from_presence(game_id)

    # Convert presence events to display format
    display_events =
      Enum.map(events, fn e ->
        case e.type do
          :goal ->
            %{minute: e.minute, team: e.team, type: :goal}

          :finished ->
            %{minute: e.minute || 45, team: nil, type: :finished}

          _ ->
            %{minute: e.minute, team: nil, type: e.type}
        end
      end)

    # Load betslip and stake from DB for authenticated users
    betslip = get_betslip_from_socket(socket)
    stake = get_stake_from_socket(socket)

    {:ok,
     socket
     |> assign(:game, game)
     |> assign(:betslip, betslip)
     |> assign(:stake, stake)
     |> assign(:sidebar_open, false)
     |> assign(:page_title, "#{game.home_team.name} vs #{game.away_team.name}")
     |> assign(:events, display_events)
     |> assign(:viewer_count, viewer_count)
     |> assign(:is_admin, is_admin)}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff"}, socket) do
    # Update viewer count when users join/leave
    presence = Presence.list(presence_topic(socket.assigns.game.id))
    viewer_count = length(Map.keys(presence))
    {:noreply, assign(socket, :viewer_count, viewer_count)}
  end

  @impl true
  def handle_info({:refresh_game, %{game_id: game_id}}, socket) do
    # Fallback: refresh from DB periodically
    game = Sport.get_game_with_teams!(game_id)
    outcomes = Bets.get_outcomes_for_game(game_id)
    game = Map.put(game, :outcomes, outcomes)

    # Schedule next refresh if game is still live
    if game.status == :live do
      schedule_refresh(game_id)
    end

    {:noreply, assign(socket, :game, game)}
  end

  defp schedule_refresh(game_id) do
    # Refresh every 5 seconds as fallback
    Process.send_after(self(), {:refresh_game, %{game_id: game_id}}, 1000)
  end

  @impl true
  def handle_event("add_to_betslip", %{"outcome_id" => outcome_id}, socket) do
    outcome = Bets.get_outcome!(outcome_id)
    game = socket.assigns.game

    betslip_contains_outcome? =
      Enum.any?(socket.assigns.betslip, fn s ->
        (Map.get(s, "outcome_id") || Map.get(s, :outcome_id)) == outcome.id
      end)

    if betslip_contains_outcome? do
      {:noreply, socket}
    else
      selection = %{
        outcome_id: outcome.id,
        game_id: game.id,
        game_name: "#{game.home_team.name} vs #{game.away_team.name}",
        label: outcome.label,
        odds: outcome.odds,
        added_at: DateTime.utc_now()
      }

      new_betslip =
        socket.assigns.betslip
        |> Enum.reject(fn s ->
          (Map.get(s, "game_id") || Map.get(s, :game_id)) == game.id
        end)
        |> Kernel.++([selection])

      # Persist to DB for authenticated users
      persist_betslip(socket, new_betslip)

      {:noreply,
       socket
       |> assign(:betslip, new_betslip)
       |> push_event("betslip_updated", %{betslip: new_betslip})}
    end
  end

  @impl true
  def handle_event("remove_from_betslip", %{"game_id" => game_id}, socket) do
    new_betslip =
      Enum.reject(socket.assigns.betslip, fn s -> s.game_id == String.to_integer(game_id) end)

    # Persist to DB for authenticated users
    persist_betslip(socket, new_betslip)

    {:noreply,
     socket
     |> assign(:betslip, new_betslip)
     |> push_event("betslip_updated", %{betslip: new_betslip})}
  end

  @impl true
  def handle_event("remove_from_betslip", %{"index" => index}, socket) do
    {_, new_betslip} = List.pop_at(socket.assigns.betslip, String.to_integer(index))

    {:noreply,
     socket
     |> assign(:betslip, new_betslip)
     |> push_event("betslip_updated", %{betslip: new_betslip})}
  end

  @impl true
  def handle_event("clear_betslip", _params, socket) do
    {:noreply,
     socket
     |> assign(:betslip, [])
     |> push_event("betslip_updated", %{betslip: []})}
  end

  @impl true
  def handle_event("toggle_sidebar", _params, socket) do
    {:noreply, assign(socket, :sidebar_open, !socket.assigns.sidebar_open)}
  end

  @impl true
  def handle_event("close_sidebar", _params, socket) do
    {:noreply, assign(socket, :sidebar_open, false)}
  end

  @impl true
  def handle_event("update_stake", %{"stake" => stake}, socket) do
    persist_stake(socket, stake)
    {:noreply, assign(socket, :stake, stake)}
  end

  @impl true
  def handle_event("place_bet", params, socket) do
    user = socket.assigns.current_scope.user

    # Get stake from params (passed from button click via phx-value-stake)
    stake_from_params = Map.get(params, "stake")
    stake_from_socket = socket.assigns[:stake] || "100"

    stake_str = stake_from_params || stake_from_socket
    stake_decimal = Decimal.new(stake_str)

    if Decimal.compare(stake_decimal, Decimal.new(0)) <= 0 do
      {:noreply, put_flash(socket, :error, "Stake must be greater than 0")}
    else
      selections = socket.assigns.betslip

      case Bets.place_betslip(user, selections, stake_decimal) do
        {:ok, _betslip} ->
          clear_betslip_from_db(socket)

          {:noreply,
           socket
           |> assign(:betslip, [])
           |> assign(:stake, "100")
           |> put_flash(:info, "Bet placed successfully!")}

        {:error, :validate_balance, :insufficient_balance, _} ->
          {:noreply, put_flash(socket, :error, "Insufficient balance to place this bet")}

        {:error, :invalid_stake, _, _} ->
          {:noreply, put_flash(socket, :error, "Stake must be greater than 0")}

        {:error, :betslip, changeset, _} ->
          {:noreply,
           put_flash(socket, :error, "Failed to place bet: #{inspect(changeset.errors)}")}

        {:error, _, _, _} ->
          {:noreply, put_flash(socket, :error, "Failed to place bet. Please try again.")}
      end
    end
  end

  defp clear_betslip_from_db(socket) do
    if socket.assigns[:current_scope] && socket.assigns.current_scope.user do
      user_id = socket.assigns.current_scope.user.id
      {:ok, _} = Bets.clear_pending_selections(user_id)
    end
  end

  # Handle GameServer events - goal scored
  @impl true
  def handle_info(
        {WaziBet.Simulation.GameServer, game_id,
         %{
           result: result,
           minute: minute,
           home_score: home_score,
           away_score: away_score,
           home_team: home_team,
           away_team: away_team
         }},
        socket
      )
      when result in [:home_score, :away_score] do
    # Track event in Presence
    track_game_event(game_id, %{
      type: :goal,
      result: result,
      minute: minute,
      home_score: home_score,
      away_score: away_score,
      team: if(result == :home_score, do: home_team, else: away_team),
      timestamp: DateTime.utc_now()
    })

    # update game
    game = socket.assigns.game

    updated_game = %{
      game
      | home_score: home_score,
        away_score: away_score,
        minute: minute
    }

    # Add goal event to the list
    team_name = if result == :home_score, do: home_team, else: away_team
    new_event = %{minute: minute, team: team_name, type: :goal}

    {:noreply,
     socket
     |> assign(:game, updated_game)
     |> assign(:events, [new_event | socket.assigns.events])}
  end

  # Handle GameServer events - game finished
  @impl true
  def handle_info(
        {WaziBet.Simulation.GameServer, game_id,
         {:finished, %{home_score: home_score, away_score: away_score}}},
        socket
      ) do
    # Track game finished in Presence
    track_game_event(game_id, %{
      type: :finished,
      home_score: home_score,
      away_score: away_score,
      timestamp: DateTime.utc_now()
    })

    game = socket.assigns.game

    updated_game = %{
      game
      | status: :finished,
        home_score: home_score,
        away_score: away_score
    }

    {:noreply,
     socket
     |> assign(:game, updated_game)
     |> put_flash(:info, "Game finished! Final score: #{home_score} - #{away_score}")}
  end

  # Handle generic game events (no goal) 
  @impl true
  def handle_info(
        {WaziBet.Simulation.GameServer, game_id, %{result: :none, minute: minute}},
        socket
      ) do
    # Update minute only from event - no DB query needed
    game = socket.assigns.game
    updated_game = %{game | minute: minute}
    {:noreply, assign(socket, :game, updated_game)}
  end

  # backwards compatibility
  @impl true
  def handle_info({:game_updated, game_id}, socket) do
    updated_game = Sport.get_game_with_teams!(game_id)
    outcomes = Bets.get_outcomes_for_game(game_id)
    updated_game = Map.put(updated_game, :outcomes, outcomes)

    {:noreply, assign(socket, :game, updated_game)}
  end

  @impl true
  def handle_info({:odds_changed, game_id}, socket) do
    outcomes = Bets.get_outcomes_for_game(game_id)
    game = Map.put(socket.assigns.game, :outcomes, outcomes)

    {:noreply, assign(socket, :game, game)}
  end

  defp subscribe_to_game(game_id) do
    Phoenix.PubSub.subscribe(WaziBet.PubSub, "game:#{game_id}")
  end

  defp presence_topic(game_id), do: "game:#{game_id}:presence"

  # Track game events - simplified version
  defp track_game_event(_game_id, _event) do
    # Game events are now handled via PubSub broadcasts directly
    # No need to store in Presence
    :ok
  end

  defp socket_id_for_presence do
    # Generate a consistent ID for presence tracking
    "game_#{:rand.uniform(999_999)}"
  end

  # Get game events from Presence
  defp get_game_events(game_id) do
    topic = presence_topic(game_id)

    Presence.list(topic)
    |> Enum.flat_map(fn {_id, %{metas: metas}} ->
      Enum.flat_map(metas, fn meta ->
        Map.get(meta, :game_events, [])
      end)
    end)
    |> Enum.sort_by(& &1.timestamp, {:desc, DateTime})
    |> Enum.take(50)
  end

  # Alias for getting events from presence
  defp get_game_events_from_presence(game_id), do: get_game_events(game_id)

  # Load betslip from DB for authenticated users
  defp get_betslip_from_socket(socket) do
    if socket.assigns[:current_scope] && socket.assigns.current_scope.user do
      user_id = socket.assigns.current_scope.user.id
      pending = Bets.get_or_create_pending_betslip(user_id)
      pending.selections || []
    else
      []
    end
  end

  defp get_stake_from_socket(socket) do
    # Always return default - stake should only come from user input in the UI
    "100"
  end

  defp persist_betslip(socket, selections) do
    if socket.assigns[:current_scope] && socket.assigns.current_scope.user do
      user_id = socket.assigns.current_scope.user.id
      {:ok, _} = Bets.update_pending_selections(user_id, selections)
    end
  end

  defp persist_stake(socket, stake) when is_binary(stake) do
    with true <- stake != "",
         {stake_num, _} <- Integer.parse(stake),
         stake_num > 0 do
      if socket.assigns[:current_scope] && socket.assigns.current_scope.user do
        user_id = socket.assigns.current_scope.user.id
        {:ok, _} = Bets.update_pending_stake(user_id, Decimal.new(stake_num))
      end
    else
      _ -> {:error, :invalid_stake}
    end
  end

  defp persist_stake(_socket, _stake), do: {:error, :invalid_stake}
end
