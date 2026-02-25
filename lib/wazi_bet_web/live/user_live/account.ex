defmodule WaziBetWeb.UserLive.Account do
  @moduledoc """
  Unified user account page showing balance, quick actions, and recent activity.
  Requires authentication.
  """

  use WaziBetWeb, :live_view

  alias WaziBet.{Bets, Accounts}

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    summary = Bets.get_user_winnings_summary(user.id)
    recent_bets = Bets.list_user_betslips(user.id) |> Enum.take(5)

    {:ok,
     socket
     |> assign(:user, user)
     |> assign(:summary, summary)
     |> assign(:recent_bets, recent_bets)
     |> assign(:deposit_form, to_form(%{"amount" => ""}))
     |> assign(:page_title, "My Account")}
  end

  #handle_event
  @impl true
  def handle_event("deposit", %{"amount" => amount}, socket) do
    user = socket.assigns.current_scope.user

    case Decimal.parse(amount) do
      {amount, _} ->
        if Decimal.compare(amount, Decimal.new(0)) == :gt do
          new_balance = Decimal.add(user.balance, amount)

          case Accounts.update_user_balance(user, new_balance) do
            {:ok, _user} ->
              summary = Bets.get_user_winnings_summary(user.id)
              user = %{user | balance: new_balance}

              {:noreply,
               socket
               |> assign(:user, user)
               |> assign(:summary, summary)
               |> assign(:deposit_form, to_form(%{"amount" => ""}))
               |> put_flash(
                 :info,
                 "Successfully deposited $#{Decimal.to_string(amount, :normal)}!"
               )}

            {:error, _} ->
              {:noreply,
               socket
               |> put_flash(:error, "Failed to deposit. Please try again.")}
          end
        else
          {:noreply,
           socket
           |> put_flash(:error, "Please enter a valid amount greater than 0.")}
        end

      _ ->
        {:noreply,
         socket
         |> put_flash(:error, "Please enter a valid amount.")}
    end
  end

  def status_color(:pending), do: "badge-warning"
  def status_color(:won), do: "badge-success"
  def status_color(:lost), do: "badge-error"
  def status_color(:void), do: "badge-ghost"
  def status_color(:cashed_out), do: "badge-info"
end
