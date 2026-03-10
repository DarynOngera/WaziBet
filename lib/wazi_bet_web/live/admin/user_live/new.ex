defmodule WaziBetWeb.Admin.UserLive.New do
  @moduledoc """
  Admin create new user view.
  Requires authentication and 'create_users' permission.
  """

  use WaziBetWeb, :live_view

  alias WaziBet.Accounts

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    current_path = "/admin/users/new"

    user_permissions = Accounts.get_user_permission_slugs(user.id)
    is_superuser = WaziBet.Can.can_slug?(user, "grant-revoke-admin-access")

    roles = Accounts.list_roles()

    changeset = Accounts.User.registration_changeset(%Accounts.User{}, %{}, validate_email: false)

    {:ok,
     socket
     |> assign(:user_permissions, user_permissions)
     |> assign(:is_superuser, is_superuser)
     |> assign(:current_path, current_path)
     |> assign(:roles, roles)
     |> assign(:changeset, changeset)
     |> assign(:page_title, "New User")}
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset =
      %Accounts.User{}
      |> Accounts.User.registration_changeset(user_params, validate_email: false)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    role_id = user_params["role_id"]

    user_params_clean = Map.drop(user_params, ["role_id"])

    case Accounts.create_user(user_params_clean) do
      {:ok, user} ->
        if role_id && role_id != "" do
          Accounts.assign_role_to_user(user.id, String.to_integer(role_id))
        end

        {:noreply,
         socket
         |> put_flash(:info, "User created successfully")
         |> push_navigate(to: ~p"/admin/users/#{user.id}")}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  def has_permission?(%WaziBet.Accounts.User{} = user, slug),
    do: WaziBet.Can.can_slug?(user, slug)

  def has_permission?(_user, _slug), do: false
end
