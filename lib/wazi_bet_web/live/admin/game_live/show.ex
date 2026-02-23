defmodule WaziBetWeb.Admin.GameLive.Show do
  @moduledoc """
  Admin game detail and edit view.
  Requires authentication and 'configure_games' permission.
  """

  use WaziBetWeb, :live_view

  alias WaziBet.{Sport, Bets}
  alias WaziBetWeb.Timezone
  alias WaziBetWeb.Presence

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    game_id = String.to_integer(id)
    game = Sport.get_game_with_teams!(game_id)
    outcomes = Bets.get_outcomes_for_game(game_id)
    game = Map.put(game, :outcomes, outcomes)

    if connected?(socket) do
      subscribe_to_game(game_id)

      Presence.track(self(), presence_topic(game_id), socket.id, %{
        user_email: socket.assigns[:current_scope] && socket.assigns.current_scope.user.email,
        joined_at: DateTime.utc_now(),
        game_events: []
      })

      Phoenix.PubSub.subscribe(WaziBet.PubSub, "presence:#{presence_topic(game_id)}")
    end

    presence = Presence.list(presence_topic(game_id))
    viewer_count = length(Map.keys(presence))
    events = get_game_events_from_presence(game_id)

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

    {:ok,
     socket
     |> assign(:game, game)
     |> assign(:viewer_count, viewer_count)
     |> assign(:events, display_events)
     |> assign(:page_title, "#{game.home_team.name} vs #{game.away_team.name}")}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff"}, socket) do
    presence = Presence.list(presence_topic(socket.assigns.game.id))
    viewer_count = length(Map.keys(presence))
    {:noreply, assign(socket, :viewer_count, viewer_count)}
  end

  @impl true
  def handle_info({:game_updated, game_id}, socket) do
    updated_game = Sport.get_game_with_teams!(game_id)
    outcomes = Bets.get_outcomes_for_game(game_id)
    updated_game = Map.put(updated_game, :outcomes, outcomes)

    {:noreply, assign(socket, :game, updated_game)}
  end

  defp subscribe_to_game(game_id) do
    Phoenix.PubSub.subscribe(WaziBet.PubSub, "game:#{game_id}")
  end

  defp presence_topic(game_id), do: "game:#{game_id}:presence"

  defp get_game_events_from_presence(game_id) do
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

  def format_starts_at(datetime) do
    Timezone.to_local(datetime)
    |> Calendar.strftime("%A, %d %B %Y at %H:%M")
  end

  def status_color(:open), do: "badge-success"
  def status_color(:closed), do: "badge-warning"
  def status_color(:settled), do: "badge-ghost"
end
