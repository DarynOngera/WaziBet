defmodule WaziBetWeb.Admin.PermissionLive.New do
  @moduledoc """
  Admin permission creation view.
  Requires authentication and 'assign-roles' permission.
  """

  use WaziBetWeb, :live_view

  alias WaziBet.Accounts

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    current_path = "/admin/permissions/new"

    user_permissions = Accounts.get_user_permission_slugs(user.id)
    is_superuser = Accounts.user_has_permission?(user.id, "grant-revoke-admin-access")

    changeset = Accounts.change_permission()

    {:ok,
     socket
     |> assign(:user_permissions, user_permissions)
     |> assign(:is_superuser, is_superuser)
     |> assign(:current_path, current_path)
     |> assign(:changeset, changeset)
     |> assign(:page_title, "New Permission")}
  end

  @impl true
  def handle_event("validate", %{"permission" => params}, socket) do
    changeset =
      %Accounts.Permission{}
      |> Accounts.change_permission(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  @impl true
  def handle_event("save", %{"permission" => params}, socket) do
    case Accounts.create_permission(params) do
      {:ok, _permission} ->
        {:noreply,
         socket
         |> put_flash(:info, "Permission created successfully")
         |> push_navigate(to: ~p"/admin/permissions")}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end
end
