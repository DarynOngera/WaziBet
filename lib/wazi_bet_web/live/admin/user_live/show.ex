defmodule WaziBetWeb.Admin.UserLive.Show do
  @moduledoc """
  Admin user detail view showing user info and their betslips.
  Requires authentication and 'view_users' permission.
  """

  use WaziBetWeb, :live_view

  alias WaziBet.{Accounts, Bets}

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    user = socket.assigns.current_scope.user
    current_path = "/admin/users/#{id}"

    user_permissions = Accounts.get_user_permission_slugs(user.id)
    is_superuser = Accounts.user_has_permission?(user.id, "grant-revoke-admin-access")

    user = Accounts.get_user_with_betslips!(id)

    betslips =
      user.betslips
      |> Enum.map(fn betslip ->
        Bets.get_betslip_with_selections!(betslip.id)
      end)
      |> Enum.sort_by(& &1.inserted_at, {:desc, NaiveDateTime})

    {:ok,
     socket
     |> assign(:user_permissions, user_permissions)
     |> assign(:is_superuser, is_superuser)
     |> assign(:current_path, current_path)
     |> assign(:user, user)
     |> assign(:betslips, betslips)
     |> assign(:page_title, "#{user.first_name} #{user.last_name}")}
  end

  def status_color(:pending), do: "badge-warning border-warning"
  def status_color(:won), do: "badge-success border-success"
  def status_color(:lost), do: "badge-error border-error"
  def status_color(:void), do: "badge-ghost border-base-300"
  def status_color(:cashed_out), do: "badge-info border-info"

  def role_badge_color("admin"), do: "badge-error"
  def role_badge_color("user"), do: "badge-info"
  def role_badge_color(_), do: "badge-ghost"

  def has_permission?(permissions, slug), do: slug in permissions
end
