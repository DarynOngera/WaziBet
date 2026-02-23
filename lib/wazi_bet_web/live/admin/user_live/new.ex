defmodule WaziBetWeb.Admin.UserLive.New do
  @moduledoc """
  Admin create new user view.
  Requires authentication and 'create_users' permission.
  """

  use WaziBetWeb, :live_view

  alias WaziBet.Accounts

  @impl true
  def mount(_params, _session, socket) do
    changeset = Accounts.User.registration_changeset(%Accounts.User{}, %{}, validate_email: false)

    {:ok,
     socket
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
    case Accounts.create_user(user_params) do
      {:ok, user} ->
        {:noreply,
         socket
         |> put_flash(:info, "User created successfully")
         |> push_navigate(to: ~p"/admin/users/#{user.id}")}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end
end
