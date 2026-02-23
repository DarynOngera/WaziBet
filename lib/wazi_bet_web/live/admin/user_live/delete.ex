defmodule WaziBetWeb.Admin.UserLive.Delete do
  @moduledoc """
  Admin soft delete user view.
  Requires authentication and 'soft_delete_users' permission.
  """

  use WaziBetWeb, :live_view

  alias WaziBet.{Accounts, Bets}

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    user = Accounts.get_user_with_betslips!(id)
    pending_bets = count_pending_bets(user)

    {:ok,
     socket
     |> assign(:user, user)
     |> assign(:pending_bets, pending_bets)
     |> assign(:page_title, "Delete User")}
  end

  @impl true
  def handle_event("confirm_delete", _params, socket) do
    user = socket.assigns.user

    case Accounts.soft_delete_user(user) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "User has been deleted successfully")
         |> push_navigate(to: ~p"/admin/users")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to delete user: #{inspect(changeset.errors)}")}
    end
  end

  defp count_pending_bets(user) do
    user.betslips
    |> Enum.count(fn betslip -> betslip.status == :pending end)
  end
end
