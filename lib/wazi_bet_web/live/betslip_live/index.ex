defmodule WaziBetWeb.BetslipLive.Index do
  @moduledoc """
  List user's betslips with status and details.
  Requires authentication and 'view_bet_history' permission.
  """

  use WaziBetWeb, :live_view

  alias WaziBet.Bets

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    betslips = Bets.list_user_betslips(user.id)
    betslips = preload_betslips(betslips)

    {:ok,
     socket
     |> assign(:betslips, betslips)
     |> assign(:page_title, "My Bets")}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  defp preload_betslips(betslips) do
    Enum.map(betslips, fn betslip ->
      Bets.get_betslip_with_selections!(betslip.id)
    end)
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
