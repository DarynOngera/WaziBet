defmodule WaziBetWeb.Admin.GameLive.Index do
  @moduledoc """
  Admin game management list view.
  Requires authentication and 'configure_games' permission.
  """

  use WaziBetWeb, :live_view

  alias WaziBet.{Sport, Bets, Accounts}
  alias WaziBetWeb.Timezone
  alias WaziBetWeb.Presence

  @page_size 10

  @impl true
  def mount(params, _session, socket) do
    user = socket.assigns.current_scope.user
    current_path = "/admin/games"

    user_permissions = Accounts.get_user_permission_slugs(user.id)
    is_superuser = WaziBet.Can.can_slug?(user, "grant-revoke-admin-access")

    page = Map.get(params, "page", "1") |> String.to_integer() |> max(1)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(WaziBet.PubSub, "games")

      Presence.track(self(), "admin:games:index", socket.id, %{
        joined_at: DateTime.utc_now()
      })

      Phoenix.PubSub.subscribe(WaziBet.PubSub, "presence:admin:games:index")
    end

    games = list_paginated_games(page)
    categories = Sport.list_categories()

    total_games = Sport.count_games()
    total_pages = ceil(total_games / @page_size)

    live_games = Enum.filter(games, &(&1.status == :live))
    viewer_counts = get_live_game_viewer_counts(live_games)

    {:ok,
     socket
     |> assign(:user_permissions, user_permissions)
     |> assign(:is_superuser, is_superuser)
     |> assign(:current_path, current_path)
     |> assign(:games, games)
     |> assign(:categories, categories)
     |> assign(:viewer_counts, viewer_counts)
     |> assign(:page_title, "Game Management")
     |> assign(:current_page, page)
     |> assign(:total_pages, total_pages)
     |> assign(:total_count, total_games)}
  end

  defp list_paginated_games(page) do
    Sport.list_games([], page: page, page_size: @page_size)
    |> Enum.map(&preload_game/1)
  end

  @impl true
  def handle_params(params, _url, socket) do
    page = Map.get(params, "page", "1") |> String.to_integer() |> max(1)
    games = list_paginated_games(page)
    total_games = Sport.count_games()
    total_pages = ceil(total_games / @page_size)
    live_games = Enum.filter(games, &(&1.status == :live))
    viewer_counts = get_live_game_viewer_counts(live_games)

    {:noreply,
     socket
     |> assign(:games, games)
     |> assign(:viewer_counts, viewer_counts)
     |> assign(:current_page, page)
     |> assign(:total_pages, total_pages)
     |> assign(:total_count, total_games)}
  end

  @impl true
  def handle_info({:game_updated, game_id}, socket) do
    updated_game = preload_game(Sport.get_game_with_teams!(game_id))

    updated_games =
      Enum.map(socket.assigns.games, fn g ->
        if g.id == game_id, do: updated_game, else: g
      end)

    live_games = Enum.filter(updated_games, &(&1.status == :live))
    viewer_counts = get_live_game_viewer_counts(live_games)

    {:noreply,
     socket
     |> assign(:games, updated_games)
     |> assign(:viewer_counts, viewer_counts)}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff"}, socket) do
    live_games = Enum.filter(socket.assigns.games, &(&1.status == :live))
    viewer_counts = get_live_game_viewer_counts(live_games)

    {:noreply, assign(socket, :viewer_counts, viewer_counts)}
  end

  defp preload_game(game) do
    game = Sport.get_game_with_teams!(game.id)
    outcomes = Bets.get_outcomes_for_game(game.id)
    Map.put(game, :outcomes, outcomes)
  end

  defp get_live_game_viewer_counts(live_games) do
    Enum.reduce(live_games, %{}, fn game, acc ->
      topic = "game:#{game.id}:presence"
      presence = Presence.list(topic)
      Map.put(acc, game.id, length(Map.keys(presence)))
    end)
  end

  def format_starts_at(datetime) do
    Timezone.to_local(datetime)
    |> Calendar.strftime("%d %b %H:%M")
  end

  def status_color(:scheduled), do: "badge-info"
  def status_color(:live), do: "badge-success"
  def status_color(:finished), do: "badge-ghost"

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
