defmodule WaziBetWeb.Admin.RoleLive.Index do
  @moduledoc """
  Admin roles list view.
  Requires authentication and 'assign_roles' permission.
  """

  use WaziBetWeb, :live_view

  alias WaziBet.Accounts

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    current_path = "/admin/roles"

    user_permissions = Accounts.get_user_permission_slugs(user.id)
    is_superuser = WaziBet.Can.can_slug?(user, "grant-revoke-admin-access")

    roles = Accounts.list_roles_with_permissions()
    permissions = Accounts.list_permissions()
    permission_groups = grouped_permissions(permissions)
    role_changeset = Accounts.Role.changeset(%Accounts.Role{}, %{})

    {:ok,
     socket
     |> assign(:user_permissions, user_permissions)
     |> assign(:is_superuser, is_superuser)
     |> assign(:current_path, current_path)
     |> assign(:roles, roles)
     |> assign(:permissions, permissions)
     |> assign(:permission_groups, permission_groups)
     |> assign(:selected_permissions, [])
     |> assign(:show_create_role_modal, false)
     |> assign(:create_role_form, to_form(role_changeset, as: :role))
     |> assign(:page_title, "Roles")}
  end

  @impl true
  def handle_event("open_create_role_modal", _params, socket) do
    role_changeset = Accounts.Role.changeset(%Accounts.Role{}, %{})

    {:noreply,
     socket
     |> assign(:show_create_role_modal, true)
     |> assign(:selected_permissions, [])
     |> assign(:create_role_form, to_form(role_changeset, as: :role))}
  end

  @impl true
  def handle_event("close_create_role_modal", _params, socket) do
    {:noreply, assign(socket, :show_create_role_modal, false)}
  end

  @impl true
  def handle_event("validate_create_role", %{"role" => params}, socket) do
    changeset =
      %Accounts.Role{}
      |> Accounts.Role.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :create_role_form, to_form(changeset, as: :role))}
  end

  @impl true
  def handle_event("toggle_permission", %{"permission_id" => permission_id}, socket) do
    permission_id = String.to_integer(permission_id)
    selected = socket.assigns.selected_permissions

    new_selected =
      if permission_id in selected do
        List.delete(selected, permission_id)
      else
        [permission_id | selected]
      end

    {:noreply, assign(socket, :selected_permissions, new_selected)}
  end

  @impl true
  def handle_event("save_create_role", %{"role" => params}, socket) do
    permission_ids = socket.assigns.selected_permissions

    case Accounts.create_role_with_permissions(params, permission_ids) do
      {:ok, _role} ->
        role_changeset = Accounts.Role.changeset(%Accounts.Role{}, %{})

        {:noreply,
         socket
         |> assign(:roles, Accounts.list_roles_with_permissions())
         |> assign(:show_create_role_modal, false)
         |> assign(:selected_permissions, [])
         |> assign(:create_role_form, to_form(role_changeset, as: :role))
         |> put_flash(:info, "Role created successfully")}

      {:error, changeset} ->
        {:noreply, assign(socket, :create_role_form, to_form(changeset, as: :role))}
    end
  end

  @impl true
  def handle_event("delete_role", %{"id" => id}, socket) do
    result =
      case Integer.parse(id) do
        {role_id, ""} ->
          role = Accounts.get_role!(role_id)

          case Accounts.delete_role(role) do
            {:ok, _role} ->
              {:ok, "Role deleted successfully"}

            {:error, :protected_role} ->
              {:error, "System roles cannot be deleted"}

            {:error, :role_in_use} ->
              {:error, "Role is assigned to users and cannot be deleted"}

            {:error, _reason} ->
              {:error, "Failed to delete role"}
          end

        _ ->
          {:error, "Invalid role id"}
      end

    socket =
      case result do
        {:ok, message} ->
          socket
          |> put_flash(:info, message)
          |> assign(:roles, Accounts.list_roles_with_permissions())

        {:error, message} ->
          put_flash(socket, :error, message)
      end

    {:noreply, socket}
  end

  def permission_badge_color("place-bets"), do: "badge-success"
  def permission_badge_color("cancel-bets"), do: "badge-warning"
  def permission_badge_color("view-bet-history"), do: "badge-info"
  def permission_badge_color("view-winnings-losses"), do: "badge-info"
  def permission_badge_color("create-users"), do: "badge-error"
  def permission_badge_color("assign-roles"), do: "badge-error"
  def permission_badge_color("grant-revoke-admin-access"), do: "badge-error"
  def permission_badge_color("view-users"), do: "badge-error"
  def permission_badge_color("view-user-games"), do: "badge-error"
  def permission_badge_color("soft-delete-users"), do: "badge-error"
  def permission_badge_color("view-profits-from-losses"), do: "badge-error"
  def permission_badge_color("configure-games"), do: "badge-error"
  def permission_badge_color(_), do: "badge-ghost"

  def group_title(:game_related), do: "Game Related"
  def group_title(:user_related), do: "User Related"
  def group_title(:other), do: "Other Permissions"
  def group_title(_), do: "Permissions"

  def grouped_permissions(permissions) do
    grouped =
      Enum.reduce(permissions, %{game_related: [], user_related: [], other: []}, fn permission,
                                                                                    acc ->
        key = permission_group(permission.slug)
        Map.update!(acc, key, &[permission | &1])
      end)

    %{
      game_related: Enum.reverse(grouped.game_related),
      user_related: Enum.reverse(grouped.user_related),
      other: Enum.reverse(grouped.other)
    }
  end

  defp permission_group(slug)
       when slug in [
              "place-bets",
              "cancel-bets",
              "view-bet-history",
              "view-winnings-losses",
              "configure-games",
              "view-user-games"
            ],
       do: :game_related

  defp permission_group(slug)
       when slug in [
              "create-users",
              "view-users",
              "soft-delete-users",
              "assign-roles",
              "grant-revoke-admin-access",
              "view-profits-from-losses"
            ],
       do: :user_related

  defp permission_group(_slug), do: :other

  def has_permission?(%WaziBet.Accounts.User{} = user, slug),
    do: WaziBet.Can.can_slug?(user, slug)

  def has_permission?(_user, _slug), do: false
end
