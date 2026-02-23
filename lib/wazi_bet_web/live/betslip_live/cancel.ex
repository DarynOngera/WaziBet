defmodule WaziBetWeb.BetslipLive.Cancel do
  @moduledoc """
  Cancel a pending betslip and refund stake.
  Requires authentication and 'cancel_bets' permission.
  """

  use WaziBetWeb, :live_view

  alias WaziBet.{Bets, Repo}
  alias WaziBet.Bets.Settlement
  alias Ecto.Multi

  @impl true
  def mount(%{"id" => betslip_id}, _session, socket) do
    user = socket.assigns.current_scope.user
    betslip_id = String.to_integer(betslip_id)
    betslip = Bets.get_betslip_with_selections!(betslip_id)

    if betslip.user_id != user.id do
      {:ok,
       socket
       |> put_flash(:error, "You can only cancel your own bets")
       |> push_navigate(to: ~p"/betslip")}
    else
      if betslip.status != :pending do
        {:ok,
         socket
         |> put_flash(:error, "Only pending bets can be cancelled")
         |> push_navigate(to: ~p"/betslip")}
      else
        {:ok,
         socket
         |> assign(:betslip, betslip)
         |> assign(:confirm_cancel, false)
         |> assign(:page_title, "Cancel Bet")}
      end
    end
  end

  @impl true
  def handle_event("confirm_cancel", _params, socket) do
    {:noreply, assign(socket, :confirm_cancel, true)}
  end

  @impl true
  def handle_event("cancel_bet", _params, socket) do
    betslip = socket.assigns.betslip

    case cancel_betslip_with_refund(betslip) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Bet cancelled successfully. Stake refunded to your balance.")
         |> push_navigate(to: ~p"/betslip")}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to cancel bet. Please try again.")}
    end
  end

  @impl true
  def handle_event("go_back", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/betslip")}
  end

  defp cancel_betslip_with_refund(betslip) do
    Multi.new()
    |> Multi.update(:betslip, Settlement.refund_betslip(betslip))
    |> Repo.transaction()
  end
end
