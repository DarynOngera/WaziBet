defmodule WaziBetWeb.GameLive.Index do
  @moduledoc """
  Public games listing page organized by category.
  Shows live games and scheduled games grouped by category.
  Accessible to both guests and authenticated users.
  """

  use WaziBetWeb, :live_view

  alias WaziBet.Sport
  alias WaziBet.Bets
  alias WaziBetWeb.GameLive.Components
  alias WaziBetWeb.Presence
  alias WaziBetWeb.Timezone

  @impl true
  def mount(params, _session, socket) do
    if connected?(socket) do
      subscribe_to_games()
      # Track presence on games index
      Presence.track(self(), "games:index", socket.id, %{
        joined_at: DateTime.utc_now()
      })

      # Subscribe to presence updates
      Phoenix.PubSub.subscribe(WaziBet.PubSub, "presence:games:index")

      # Subscribe to pending betslip updates if authenticated
      if socket.assigns[:current_scope] && socket.assigns.current_scope.user do
        user_id = socket.assigns.current_scope.user.id
        Phoenix.PubSub.subscribe(WaziBet.PubSub, "user:#{user_id}:pending_betslip")
      end
    end

    categories = Sport.list_categories()
    selected_category = params["category"]

    games = list_games_with_outcomes(selected_category)
    games_by_category = organize_games_by_category(games, categories)
    {live_games_by_category, scheduled_games_by_category} = split_games_by_tab(games_by_category)
    games_tab = default_games_tab(live_games_by_category, scheduled_games_by_category)

    # Get viewer counts for live games
    viewer_counts = get_live_game_viewer_counts(games)

    # Load betslip and stake from storage (DB for authenticated users)
    betslip = get_betslip_from_storage(socket)
    stake = get_stake_from_storage(socket)
    total_odds = calculate_total_odds(betslip)
    potential_payout = calculate_potential_payout(stake, total_odds)

    {:ok,
     socket
     |> assign(:categories, categories)
     |> assign(:selected_category, selected_category)
     |> assign(:games_by_category, games_by_category)
     |> assign(:live_games_by_category, live_games_by_category)
     |> assign(:scheduled_games_by_category, scheduled_games_by_category)
     |> assign(:games_tab, games_tab)
     |> assign(:viewer_counts, viewer_counts)
     |> assign(:betslip, betslip)
     |> assign(:stake, stake)
     |> assign(:total_odds, total_odds)
     |> assign(:potential_payout, potential_payout)
     |> assign(:page_title, "Games")}
  end

  @impl true
  def handle_params(params, _url, socket) do
    selected_category = params["category"]
    games = list_games_with_outcomes(selected_category)
    games_by_category = organize_games_by_category(games, socket.assigns.categories)
    {live_games_by_category, scheduled_games_by_category} = split_games_by_tab(games_by_category)

    games_tab =
      choose_games_tab(
        socket.assigns[:games_tab],
        live_games_by_category,
        scheduled_games_by_category
      )

    {:noreply,
     socket
     |> assign(:games_by_category, games_by_category)
     |> assign(:live_games_by_category, live_games_by_category)
     |> assign(:scheduled_games_by_category, scheduled_games_by_category)
     |> assign(:games_tab, games_tab)
     |> assign(:selected_category, selected_category)}
  end

  @impl true
  def handle_event("select_category", %{"category_id" => category_id}, socket) do
    {:noreply, push_patch(socket, to: ~p"/?category=#{category_id}")}
  end

  @impl true
  def handle_event("clear_filter", _params, socket) do
    {:noreply, push_patch(socket, to: ~p"/")}
  end

  @impl true
  def handle_event("switch_games_tab", %{"tab" => tab}, socket)
      when tab in ["live", "scheduled"] do
    {:noreply, assign(socket, :games_tab, String.to_existing_atom(tab))}
  end

  @impl true
  def handle_event("add_to_betslip", %{"outcome_id" => outcome_id}, socket) do
    outcome = Bets.get_outcome!(outcome_id)
    game = Sport.get_game_with_teams!(outcome.game_id)

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
       |> assign(:total_odds, calculate_total_odds(new_betslip))
       |> assign(
         :potential_payout,
         calculate_potential_payout(socket.assigns.stake, calculate_total_odds(new_betslip))
       )
       |> push_event("betslip_updated", %{betslip: new_betslip})}
    end
  end

  @impl true
  def handle_event("remove_from_betslip", %{"index" => index}, socket) do
    {_, new_betslip} = List.pop_at(socket.assigns.betslip, String.to_integer(index))

    # Persist to DB for authenticated users
    persist_betslip(socket, new_betslip)

    new_total_odds = calculate_total_odds(new_betslip)

    {:noreply,
     socket
     |> assign(:betslip, new_betslip)
     |> assign(:total_odds, new_total_odds)
     |> assign(
       :potential_payout,
       calculate_potential_payout(socket.assigns.stake, new_total_odds)
     )
     |> push_event("betslip_updated", %{betslip: new_betslip})}
  end

  @impl true
  def handle_event("clear_betslip", _params, socket) do
    # Clear from DB for authenticated users
    clear_betslip_from_db(socket)

    {:noreply,
     socket
     |> assign(:betslip, [])
     |> assign(:total_odds, Decimal.new(1))
     |> assign(:potential_payout, Decimal.new(0))
     |> push_event("betslip_updated", %{betslip: []})}
  end

  @impl true
  def handle_event("update_stake", %{"stake" => stake}, socket) do
    stake_str = stake |> to_string() |> String.trim()

    stake_decimal =
      case stake_str do
        "" -> Decimal.new(0)
        _ -> Decimal.new(stake_str)
      end

    stake_decimal = Decimal.round(stake_decimal, 2)
    persist_stake(socket, Decimal.to_string(stake_decimal, :normal))

    potential_payout = Decimal.mult(stake_decimal, socket.assigns.total_odds)

    {:noreply,
     socket
     |> assign(:stake, Decimal.to_string(stake_decimal, :normal))
     |> assign(:potential_payout, potential_payout)}
  end

  @impl true
  def handle_event("place_bet", %{"stake" => stake} = _params, socket) do
    user = socket.assigns.current_scope.user

    stake_decimal =
      stake
      |> to_string()
      |> String.trim()
      |> then(fn
        "" -> Decimal.new(0)
        val -> Decimal.new(val)
      end)
      |> Decimal.round(2)

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
           |> assign(:total_odds, Decimal.new(1))
           |> assign(:potential_payout, Decimal.new(0))
           |> put_flash(:info, "Bet placed successfully!")}

        {:error, :validate_balance, :insufficient_balance, _} ->
          {:noreply, put_flash(socket, :error, "Insufficient balance to place this bet")}

        {:error, :invalid_stake, _, _} ->
          {:noreply, put_flash(socket, :error, "Stake must be greater than 0")}

        {:error, :betslip, changeset, _} ->
          {:noreply, put_flash(socket, :error, "Failed to place bet: #{inspect(changeset)}")}

        {:error, _, _, _} ->
          {:noreply, put_flash(socket, :error, "Failed to place bet. Please try again.")}
      end
    end
  end

  @impl true
  def handle_info({:game_updated, game_id}, socket) do
    updated_game = Sport.get_game_with_teams!(game_id)

    games_by_category =
      Enum.map(socket.assigns.games_by_category, fn %{
                                                      category: _category,
                                                      live_games: live,
                                                      scheduled_games: scheduled
                                                    } = group ->
        updated_live = update_game_in_list(live, updated_game)
        updated_scheduled = update_game_in_list(scheduled, updated_game)
        %{group | live_games: updated_live, scheduled_games: updated_scheduled}
      end)

    {live_games_by_category, scheduled_games_by_category} = split_games_by_tab(games_by_category)

    games_tab =
      choose_games_tab(
        socket.assigns.games_tab,
        live_games_by_category,
        scheduled_games_by_category
      )

    {:noreply,
     socket
     |> assign(:games_by_category, games_by_category)
     |> assign(:live_games_by_category, live_games_by_category)
     |> assign(:scheduled_games_by_category, scheduled_games_by_category)
     |> assign(:games_tab, games_tab)}
  end

  @impl true
  def handle_info({WaziBet.Workers.GameStartWorker, game_id, :started}, socket) do
    started_game = enrich_game_for_index(Sport.get_game_with_teams!(game_id))

    games_by_category =
      Enum.map(socket.assigns.games_by_category, fn %{
                                                      category: category,
                                                      live_games: live,
                                                      scheduled_games: scheduled
                                                    } = group ->
        updated_live =
          if category.id == started_game.category_id do
            [started_game | Enum.reject(live, &(&1.id == game_id))]
          else
            Enum.reject(live, &(&1.id == game_id))
          end

        updated_scheduled = Enum.reject(scheduled, &(&1.id == game_id))

        %{group | live_games: updated_live, scheduled_games: updated_scheduled}
      end)
      |> Enum.reject(fn %{live_games: live, scheduled_games: scheduled} ->
        Enum.empty?(live) and Enum.empty?(scheduled)
      end)

    {live_games_by_category, scheduled_games_by_category} = split_games_by_tab(games_by_category)

    games_tab =
      choose_games_tab(
        socket.assigns.games_tab,
        live_games_by_category,
        scheduled_games_by_category
      )

    viewer_counts =
      get_live_game_viewer_counts(flatten_grouped_games(live_games_by_category, :live_games))

    {:noreply,
     socket
     |> assign(:games_by_category, games_by_category)
     |> assign(:live_games_by_category, live_games_by_category)
     |> assign(:scheduled_games_by_category, scheduled_games_by_category)
     |> assign(:games_tab, games_tab)
     |> assign(:viewer_counts, viewer_counts)}
  end

  @impl true
  def handle_info(
        {WaziBet.Simulation.GameServer, game_id,
         %{minute: minute, home_score: home_score, away_score: away_score}},
        socket
      ) do
    games_by_category =
      Enum.map(socket.assigns.games_by_category, fn %{
                                                      live_games: live,
                                                      scheduled_games: scheduled
                                                    } = group ->
        updated_live =
          Enum.map(live, fn game ->
            if game.id == game_id do
              %{
                game
                | minute: minute,
                  home_score: home_score,
                  away_score: away_score,
                  status: :live
              }
            else
              game
            end
          end)

        updated_scheduled =
          update_game_in_list(scheduled, %{
            id: game_id,
            status: :live,
            minute: minute,
            home_score: home_score,
            away_score: away_score
          })

        %{group | live_games: updated_live, scheduled_games: updated_scheduled}
      end)

    {live_games_by_category, scheduled_games_by_category} = split_games_by_tab(games_by_category)

    games_tab =
      choose_games_tab(
        socket.assigns.games_tab,
        live_games_by_category,
        scheduled_games_by_category
      )

    {:noreply,
     socket
     |> assign(:games_by_category, games_by_category)
     |> assign(:live_games_by_category, live_games_by_category)
     |> assign(:scheduled_games_by_category, scheduled_games_by_category)
     |> assign(:games_tab, games_tab)}
  end

  @impl true
  def handle_info({WaziBet.Simulation.GameServer, game_id, {:finished, _payload}}, socket) do
    handle_info({:game_updated, game_id}, socket)
  end

  @impl true
  def handle_info({:odds_changed, game_id}, socket) do
    outcomes = Bets.get_outcomes_for_game(game_id)

    games_by_category =
      Enum.map(socket.assigns.games_by_category, fn %{
                                                      live_games: live,
                                                      scheduled_games: scheduled
                                                    } = group ->
        updated_live = update_outcomes_in_list(live, game_id, outcomes)
        updated_scheduled = update_outcomes_in_list(scheduled, game_id, outcomes)
        %{group | live_games: updated_live, scheduled_games: updated_scheduled}
      end)

    {live_games_by_category, scheduled_games_by_category} = split_games_by_tab(games_by_category)

    games_tab =
      choose_games_tab(
        socket.assigns.games_tab,
        live_games_by_category,
        scheduled_games_by_category
      )

    {:noreply,
     socket
     |> assign(:games_by_category, games_by_category)
     |> assign(:live_games_by_category, live_games_by_category)
     |> assign(:scheduled_games_by_category, scheduled_games_by_category)
     |> assign(:games_tab, games_tab)}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff"}, socket) do
    games = list_games_with_outcomes(socket.assigns.selected_category)
    live_games = Enum.filter(games, &(&1.status == :live))
    viewer_counts = get_live_game_viewer_counts(live_games)

    {:noreply, assign(socket, :viewer_counts, viewer_counts)}
  end

  defp list_games_with_outcomes(category_filter) do
    filters =
      if category_filter, do: [{:category_id, String.to_integer(category_filter)}], else: []

    filters
    |> Sport.list_games()
    |> Enum.map(&enrich_game_for_index/1)
  end

  defp organize_games_by_category(games, categories) do
    categories
    |> Enum.map(fn category ->
      category_games = Enum.filter(games, &(&1.category_id == category.id))
      live = Enum.filter(category_games, &(&1.status == :live))
      scheduled = Enum.filter(category_games, &(&1.status == :scheduled))

      %{
        category: category,
        live_games: live,
        scheduled_games: scheduled
      }
    end)
    |> Enum.reject(fn %{live_games: live, scheduled_games: scheduled} ->
      Enum.empty?(live) and Enum.empty?(scheduled)
    end)
  end

  defp split_games_by_tab(games_by_category) do
    live_games_by_category =
      Enum.filter(games_by_category, fn %{live_games: live} -> live != [] end)

    scheduled_games_by_category =
      Enum.filter(games_by_category, fn %{scheduled_games: scheduled} -> scheduled != [] end)

    {live_games_by_category, scheduled_games_by_category}
  end

  defp default_games_tab(live_games_by_category, scheduled_games_by_category) do
    choose_games_tab(nil, live_games_by_category, scheduled_games_by_category)
  end

  defp choose_games_tab(:live, live_games_by_category, scheduled_games_by_category) do
    cond do
      live_games_by_category != [] -> :live
      scheduled_games_by_category != [] -> :scheduled
      true -> :live
    end
  end

  defp choose_games_tab(:scheduled, live_games_by_category, scheduled_games_by_category) do
    cond do
      scheduled_games_by_category != [] -> :scheduled
      live_games_by_category != [] -> :live
      true -> :scheduled
    end
  end

  defp choose_games_tab(nil, live_games_by_category, scheduled_games_by_category) do
    cond do
      live_games_by_category != [] -> :live
      scheduled_games_by_category != [] -> :scheduled
      true -> :live
    end
  end

  defp games_count(groups, key) do
    Enum.reduce(groups, 0, fn group, acc -> acc + length(Map.fetch!(group, key)) end)
  end

  defp flatten_grouped_games(groups, key) do
    Enum.flat_map(groups, &Map.fetch!(&1, key))
  end

  defp update_game_in_list(games, updated_game) do
    Enum.map(games, fn game ->
      if game.id == updated_game.id do
        Map.merge(game, Map.take(updated_game, [:status, :home_score, :away_score, :minute]))
      else
        game
      end
    end)
  end

  defp enrich_game_for_index(game) do
    game = Sport.get_game_with_teams!(game.id)
    outcomes = Bets.get_outcomes_for_game(game.id)
    Map.put(game, :outcomes, outcomes)
  end

  defp update_outcomes_in_list(games, game_id, outcomes) do
    Enum.map(games, fn game ->
      if game.id == game_id do
        %{game | outcomes: outcomes}
      else
        game
      end
    end)
  end

  defp subscribe_to_games do
    Phoenix.PubSub.subscribe(WaziBet.PubSub, "games")
  end

  defp get_live_game_viewer_counts(live_games) do
    Enum.reduce(live_games, %{}, fn game, acc ->
      topic = "game:#{game.id}:presence"
      presence = Presence.list(topic)
      Map.put(acc, game.id, length(Map.keys(presence)))
    end)
  end

  defp get_betslip_from_storage(socket) do
    # For authenticated users, load from DB
    if socket.assigns[:current_scope] && socket.assigns.current_scope.user do
      user_id = socket.assigns.current_scope.user.id
      pending = Bets.get_or_create_pending_betslip(user_id)
      pending.selections || []
    else
      # For guests, use empty list
      []
    end
  end

  defp get_stake_from_storage(socket) do
    # Always return default - stake should only come from user input in the UI
    # Don't read from DB as it might have stale/0 values
    "100"
  end

  defp persist_betslip(socket, selections) do
    if socket.assigns[:current_scope] && socket.assigns.current_scope.user do
      user_id = socket.assigns.current_scope.user.id
      {:ok, _} = Bets.update_pending_selections(user_id, selections)
    end
  end

  defp persist_stake(socket, stake) when is_binary(stake) do
    stake_decimal = Decimal.new(stake)

    if Decimal.compare(stake_decimal, Decimal.new(0)) > 0 do
      if socket.assigns[:current_scope] && socket.assigns.current_scope.user do
        user_id = socket.assigns.current_scope.user.id
        {:ok, _} = Bets.update_pending_stake(user_id, stake_decimal)
      end
    else
      {:error, :invalid_stake}
    end
  end

  defp persist_stake(_socket, _stake), do: {:error, :invalid_stake}

  defp clear_betslip_from_db(socket) do
    if socket.assigns[:current_scope] && socket.assigns.current_scope.user do
      user_id = socket.assigns.current_scope.user.id
      {:ok, _} = Bets.clear_pending_selections(user_id)
    end
  end

  def format_score(%{status: :scheduled}), do: "vs"
  def format_score(game), do: "#{game.home_score} - #{game.away_score}"

  def total_live_games(groups), do: games_count(groups, :live_games)
  def total_scheduled_games(groups), do: games_count(groups, :scheduled_games)

  def format_local_starts_at(datetime, format) do
    datetime
    |> Timezone.to_local()
    |> Calendar.strftime(format)
  end

  def status_color(:scheduled), do: "badge-info"
  def status_color(:live), do: "badge-success"
  def status_color(:finished), do: "badge-ghost"

  # Game card component
  attr :game, :map, required: true
  attr :betslip, :list, required: true
  attr :viewer_count, :integer, default: 0

  def game_card(assigns) do
    ~H"""
    <div class="card bg-base-100 shadow-2xs border border-base-300 hover:border-primary transition-colors">
      <div class="card-body p-2">
        <div class="flex flex-col lg:flex-row gap-4">
          <%!-- Match Info --%>
          <div class="flex-1 flex items-center gap-4">
            <%!-- Time/Status --%>
            <div class="text-center min-w-[80px]">
              <%= if @game.status == :live do %>
                <div class="text-success font-bold font-mono text-lg">
                  {@game.minute}'
                </div>
                <div class="text-xs text-success flex items-center justify-center gap-1">
                  <span class="w-2 h-2 bg-success rounded-full animate-pulse"></span> LIVE
                </div>
                <%= if @viewer_count > 0 do %>
                  <div class="text-xs text-base-content/60 mt-1 flex items-center justify-center gap-1">
                    <.icon name="hero-eye" class="w-3 h-3" />
                    {@viewer_count}
                  </div>
                <% end %>
              <% else %>
                <div class="text-sm font-mono">
                  {format_local_starts_at(@game.starts_at, "%d %b")}
                </div>
                <div class="text-xs text-base-content/60">
                  {format_local_starts_at(@game.starts_at, "%H:%M")}
                </div>
              <% end %>
            </div>

            <%!-- Teams --%>
            <div class="flex-1">
              <div class="flex items-center justify-between gap-4">
                <div class="flex-1">
                  <div class="font-medium">{@game.home_team.name}</div>
                  <%= if @game.status != :scheduled do %>
                    <div class="text-xs text-base-content/60">
                      <.icon name="hero-bolt" class="w-3 h-3 text-warning" /> {@game.home_team.attack_rating}
                      <.icon name="hero-shield" class="w-3 h-3 text-info ml-1" /> {@game.home_team.defense_rating}
                    </div>
                  <% end %>
                </div>

                <div class="text-center px-4">
                  <div class="text-2xl font-bold font-mono bg-base-200 px-3 py-1 rounded-lg">
                    {format_score(@game)}
                  </div>
                </div>

                <div class="flex-1 text-right">
                  <div class="font-medium">{@game.away_team.name}</div>
                  <%= if @game.status != :scheduled do %>
                    <div class="text-xs text-base-content/60">
                      <.icon name="hero-bolt" class="w-3 h-3 text-warning" /> {@game.away_team.attack_rating}
                      <.icon name="hero-shield" class="w-3 h-3 text-info ml-1" /> {@game.away_team.defense_rating}
                    </div>
                  <% end %>
                </div>
              </div>
            </div>
          </div>

          <%!-- Odds --%>
          <%= if @game.status == :scheduled do %>
            <div class="flex gap-2 lg:justify-end p-1">
              <%= for outcome <- sort_outcomes(@game.outcomes) do %>
                <button
                  phx-click="add_to_betslip"
                  phx-value-outcome_id={outcome.id}
                  class={[
                    "btn border-2 font-mono min-w-[80px]",
                    if(Components.is_selected?(@betslip, outcome.id),
                      do: "btn-primary ring-2 ring-offset-2 ring-primary",
                      else: "btn-outline btn-primary hover:scale-105"
                    )
                  ]}
                >
                  <div class="flex flex-col items-center">
                    <span class="text-xs opacity-70">
                      <%= case outcome.label do %>
                        <% :home -> %>
                          1
                        <% :draw -> %>
                          X
                        <% :away -> %>
                          2
                      <% end %>
                    </span>
                    <span class="font-bold">{outcome.odds}</span>
                  </div>
                </button>
              <% end %>
            </div>
          <% else %>
            <div class="flex items-center justify-center lg:justify-end">
              <.link navigate={~p"/games/#{@game.id}"} class="btn btn-ghost btn-sm">
                <.icon name="hero-eye" class="w-5 h-5" />
                <span class="hidden sm:inline ml-2">View</span>
              </.link>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # Helper function to render category icons as inline SVG
  attr :icon, :string, required: true
  attr :class, :string, default: "w-5 h-5"

  def category_icon(assigns) do
    ~H"""
    <%= case @icon do %>
      <% "hero-trophy" -> %>
        <svg
          xmlns="http://www.w3.org/2000/svg"
          fill="none"
          viewBox="0 0 24 24"
          stroke-width="1.5"
          stroke="currentColor"
          class={@class}
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            d="M16.5 18.75h-9m9 0a3 3 0 0 1 3 3h-15a3 3 0 0 1 3-3m9 0v-3.375c0-.621-.503-1.125-1.125-1.125h-.871M7.5 18.75v-3.375c0-.621.504-1.125 1.125-1.125h.872m5.007 0H9.497m5.007 0a7.454 7.454 0 0 1-.982-3.172M9.497 14.25a7.454 7.454 0 0 0 .981-3.172M5.25 4.236c-.982.143-1.954.317-2.916.52A6.003 6.003 0 0 0 7.73 9.728M5.25 4.236V4.5c0 2.108.966 3.99 2.48 5.228M5.25 4.236V2.721C7.456 2.41 9.71 2.25 12 2.25c2.291 0 4.545.16 6.75.47v1.516M7.73 9.728a6.726 6.726 0 0 0 2.748 1.35m8.272-6.842V4.5c0 2.108-.966 3.99-2.48 5.228m2.48-5.492a46.32 46.32 0 0 1 2.916.52 6.003 6.003 0 0 1-5.395 4.972m0 0a6.726 6.726 0 0 1-2.749 1.35m0 0a6.772 6.772 0 0 1-3.044 0"
          />
        </svg>
      <% "hero-fire" -> %>
        <svg
          xmlns="http://www.w3.org/2000/svg"
          fill="none"
          viewBox="0 0 24 24"
          stroke-width="1.5"
          stroke="currentColor"
          class={@class}
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            d="M15.362 5.214A8.252 8.252 0 0 1 12 21 8.25 8.25 0 0 1 6.038 7.047 8.287 8.287 0 0 0 9 9.601a8.983 8.983 0 0 1 3.361-6.867 8.21 8.21 0 0 0 3 2.48Z"
          />
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            d="M12 18a3.75 3.75 0 0 0 .495-7.468 5.99 5.99 0 0 0-1.925 3.547 5.975 5.975 0 0 1-2.133-1.001A3.75 3.75 0 0 0 12 18Z"
          />
        </svg>
      <% "hero-star" -> %>
        <svg
          xmlns="http://www.w3.org/2000/svg"
          fill="none"
          viewBox="0 0 24 24"
          stroke-width="1.5"
          stroke="currentColor"
          class={@class}
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            d="M11.48 3.499a.562.562 0 0 1 1.04 0l2.125 5.111a.563.563 0 0 0 .475.345l5.518.442c.499.04.701.663.321.988l-4.204 3.602a.563.563 0 0 0-.182.557l1.285 5.385a.562.562 0 0 1-.84.61l-4.725-2.885a.562.562 0 0 0-.586 0L6.982 20.54a.562.562 0 0 1-.84-.61l1.285-5.386a.562.562 0 0 0-.182-.557l-4.204-3.602a.562.562 0 0 1 .321-.988l5.518-.442a.563.563 0 0 0 .475-.345L11.48 3.5Z"
          />
        </svg>
      <% "hero-users" -> %>
        <svg
          xmlns="http://www.w3.org/2000/svg"
          fill="none"
          viewBox="0 0 24 24"
          stroke-width="1.5"
          stroke="currentColor"
          class={@class}
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            d="M15 19.128a9.38 9.38 0 0 0 2.625.372 9.337 9.337 0 0 0 4.121-.952 4.125 4.125 0 0 0-7.533-2.493M15 19.128v-.003c0-1.113-.285-2.16-.786-3.07M15 19.128v.106A12.318 12.318 0 0 1 8.624 21c-2.331 0-4.512-.645-6.374-1.766l-.001-.109a6.375 6.375 0 0 1 11.964-3.07M12 6.375a3.375 3.375 0 1 1-6.75 0 3.375 3.375 0 0 1 6.75 0Zm8.25 2.25a2.625 2.625 0 1 1-5.25 0 2.625 2.625 0 0 1 5.25 0Z"
          />
        </svg>
      <% _ -> %>
        <.icon name={@icon} class={@class} />
    <% end %>
    """
  end

  defp calculate_total_odds([]), do: Decimal.new(1)

  defp calculate_total_odds(betslip) do
    Enum.reduce(betslip, Decimal.new(1), fn selection, acc ->
      odds = get_odds(selection)
      Decimal.mult(acc, odds)
    end)
  end

  defp get_odds(selection) do
    odds_value =
      selection
      |> Map.get(:odds)
      |> Kernel.||(Map.get(selection, "odds", 1))

    case odds_value do
      %Decimal{} ->
        odds_value

      %{"coef" => coef, "exp" => exp, "sign" => sign} ->
        %Decimal{coef: coef, exp: exp, sign: sign}

      nil ->
        Decimal.new(1)

      val when is_number(val) ->
        Decimal.new(val)

      val when is_binary(val) ->
        Decimal.new(val)

      _ ->
        Decimal.new(1)
    end
  end

  defp get_field(map, key, default \\ nil) do
    Map.get(map, key) |> Kernel.||(Map.get(map, to_string(key), default))
  end

  defp format_odds(odds) do
    odds
  end

  defp calculate_potential_payout(stake, total_odds) do
    stake_val = if stake == "" or stake == nil, do: "0", else: stake
    stake_decimal = Decimal.new(stake_val)
    Decimal.mult(stake_decimal, total_odds)
  end

  defp sort_outcomes(outcomes) do
    order = %{home: 0, draw: 1, away: 2}
    Enum.sort_by(outcomes, &Map.get(order, &1.label, 99))
  end
end
