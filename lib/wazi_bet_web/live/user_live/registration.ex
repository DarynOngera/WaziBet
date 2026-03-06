defmodule WaziBetWeb.UserLive.Registration do
  use WaziBetWeb, :live_view

  alias WaziBet.Accounts
  alias WaziBet.Accounts.User

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-md">
        <div class="card bg-base-100 shadow-xl border border-base-300">
          <div class="card-body p-8">
            <div class="text-center mb-8">
              <div class="w-16 h-16 mx-auto mb-4 rounded-full bg-secondary/10 flex items-center justify-center">
                <.icon name="hero-user-plus" class="w-8 h-8 text-secondary" />
              </div>
              <h1 class="text-2xl font-bold">Create Account</h1>
              <p class="text-base-content/60 mt-2">
                Already registered?
                <.link navigate={~p"/users/log-in"} class="font-semibold text-primary hover:underline">
                  Log in
                </.link>
                to your account.
              </p>
            </div>

            <.form for={@form} id="registration_form" phx-submit="save" phx-change="validate">
              <.input
                field={@form[:email]}
                type="email"
                label="Email"
                autocomplete="username"
                required
                phx-mounted={JS.focus()}
              />

              <.input
                field={@form[:password]}
                type="password"
                label="Password"
                autocomplete="new-password"
                required
              />

              <.input
                field={@form[:password_confirmation]}
                type="password"
                label="Confirm Password"
                autocomplete="new-password"
                required
              />

              <div class="grid grid-cols-2 gap-4">
                <.input
                  field={@form[:first_name]}
                  type="text"
                  label="First Name"
                  autocomplete="given-name"
                />

                <.input
                  field={@form[:last_name]}
                  type="text"
                  label="Last Name"
                  autocomplete="family-name"
                />
              </div>

              <.input
                field={@form[:msisdn]}
                type="tel"
                label="Phone Number"
                placeholder="+1234567890"
              />

              <button
                type="submit"
                phx-disable-with="Creating account..."
                class="btn btn-primary w-full border-2 mt-6"
              >
                <.icon name="hero-user-plus" class="w-5 h-5 mr-2" /> Create an account
              </button>
            </.form>

            <div class="mt-6 text-center">
              <p class="text-sm text-base-content/50">
                By creating an account, you agree to our Terms of Service and Privacy Policy.
              </p>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: %{user: user}}} = socket)
      when not is_nil(user) do
    {:ok, redirect(socket, to: WaziBetWeb.UserAuth.signed_in_path(socket))}
  end

  def mount(_params, _session, socket) do
    changeset = User.registration_changeset(%User{}, %{})

    {:ok, assign_form(socket, changeset), temporary_assigns: [form: nil]}
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        {:ok, _} =
          Accounts.deliver_login_instructions(
            user,
            &url(~p"/users/log-in/#{&1}")
          )

        {:noreply,
         socket
         |> put_flash(
           :info,
           "An email was sent to #{user.email}, please access it to confirm your account."
         )
         |> push_navigate(to: ~p"/users/log-in")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = User.registration_changeset(%User{}, user_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")
    assign(socket, form: form)
  end
end
