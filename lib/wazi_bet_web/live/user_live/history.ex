defmodule WaziBetWeb.UserLive.History do
  @moduledoc """
  User betting history - index and show views.
  Requires authentication and 'view_bet_history' permission.
  """


  use WaziBetWeb, :live_view

  alias WaziBet.{Bets, Repo}

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    user = socket.assigns.current_scope.user

    betslip =
      Bets.get_betslip_with_selections!(id)
      |> Repo.preload(selections: [:outcome, game: [:home_team, :away_team]])

    if betslip.user_id == user.id do
      {:ok,
       socket
       |> assign(:betslip, betslip)
       |> assign(:page_title, "Bet Details")
       |> assign(:view, :show)}
    else
      {:ok,
       socket
       |> put_flash(:error, "You don't have access to this betslip")
       |> push_navigate(to: ~p"/history")}
    end
  end

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    betslips = Bets.list_user_betslips(user.id)

    betslips =
      Enum.map(betslips, fn betslip ->
        Bets.get_betslip_with_selections!(betslip.id)
      end)

    {:ok,
     socket
     |> assign(:betslips, betslips)
     |> assign(:page_title, "Betting History")
     |> assign(:view, :index)}
  end

  @impl true
  def handle_params(%{"id" => _id}, _url, socket) do
    {:noreply, assign(socket, :view, :show)}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, assign(socket, :view, :index)}
  end

  def status_color(:pending), do: "badge-warning border-warning"
  def status_color(:won), do: "badge-success border-success"
  def status_color(:lost), do: "badge-error border-error"
  def status_color(:void), do: "badge-ghost border-base-300"
  def status_color(:cashed_out), do: "badge-info border-info"

  def selection_icon(:pending), do: "hero-clock"
  def selection_icon(:won), do: "hero-check-circle"
  def selection_icon(:lost), do: "hero-x-circle"
  def selection_icon(:void), do: "hero-minus-circle"

  def selection_status_color(:pending), do: "text-base-content/60"
  def selection_status_color(:won), do: "text-success"
  def selection_status_color(:lost), do: "text-error"
  def selection_status_color(:void), do: "text-base-content/60"
end
