defmodule WaziBetWeb.UserLive.Login do
  use WaziBetWeb, :live_view

  alias WaziBet.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-md">
        <div class="card bg-base-100 shadow-xl border border-base-300">
          <div class="card-body p-8">
            <div class="text-center mb-8">
              <div class="w-16 h-16 mx-auto mb-4 rounded-full bg-primary/10 flex items-center justify-center">
                <.icon name="hero-arrow-right-on-rectangle" class="w-8 h-8 text-primary" />
              </div>
              <h1 class="text-2xl font-bold">Log in</h1>
              <p class="text-base-content/60 mt-2">
                <%= if @current_scope do %>
                  You need to reauthenticate to perform sensitive actions on your account.
                <% else %>
                  Don't have an account?
                  <.link
                    navigate={~p"/users/register"}
                    class="font-semibold text-primary hover:underline"
                  >
                    Sign up
                  </.link>
                <% end %>
              </p>
            </div>

            <div :if={local_mail_adapter?()} class="alert alert-info mb-6 border-2 border-info">
              <.icon name="hero-information-circle" class="w-6 h-6 shrink-0" />
              <div>
                <p class="font-medium">You are running the local mail adapter.</p>
                <p class="text-sm">
                  To see sent emails, visit <.link href="/dev/mailbox" class="underline">the mailbox page</.link>.
                </p>
              </div>
            </div>

            <%!-- Magic Link Login --%>
            <.form
              :let={f}
              for={@form}
              id="login_form_magic"
              action={~p"/users/log-in"}
              phx-submit="submit_magic"
            >
              <.input
                readonly={!!@current_scope}
                field={f[:email]}
                type="email"
                label="Email"
                autocomplete="email"
                required
                phx-mounted={JS.focus()}
              />
              <button type="submit" class="btn btn-primary w-full border-2 mt-4">
                <.icon name="hero-envelope" class="w-5 h-5 mr-2" /> Log in with email
                <.icon name="hero-arrow-right" class="w-4 h-4 ml-2" />
              </button>
            </.form>

            <div class="divider my-6">or</div>

            <%!-- Password Login --%>
            <.form
              :let={f}
              for={@form}
              id="login_form_password"
              action={~p"/users/log-in"}
              phx-submit="submit_password"
              phx-trigger-action={@trigger_submit}
            >
              <.input
                readonly={!!@current_scope}
                field={f[:email]}
                type="email"
                label="Email"
                autocomplete="email"
                required
              />
              <.input
                field={@form[:password]}
                type="password"
                label="Password"
                autocomplete="current-password"
              />
              <button
                type="submit"
                class="btn btn-primary w-full border-2 mt-4"
                name={@form[:remember_me].name}
                value="true"
              >
                <.icon name="hero-key" class="w-5 h-5 mr-2" /> Log in and stay logged in
              </button>
              <button type="submit" class="btn btn-ghost w-full mt-2">
                Log in only this time
              </button>
            </.form>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    email =
      Phoenix.Flash.get(socket.assigns.flash, :email) ||
        get_in(socket.assigns, [:current_scope, Access.key(:user), Access.key(:email)])

    form = to_form(%{"email" => email}, as: "user")

    {:ok, assign(socket, form: form, trigger_submit: false)}
  end

  @impl true
  def handle_event("submit_password", _params, socket) do
    {:noreply, assign(socket, :trigger_submit, true)}
  end

  def handle_event("submit_magic", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_login_instructions(
        user,
        &url(~p"/users/log-in/#{&1}")
      )
    end

    info =
      "If your email is in our system, you will receive instructions for logging in shortly."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> push_navigate(to: ~p"/users/log-in")}
  end

  defp local_mail_adapter? do
    Application.get_env(:wazi_bet, WaziBet.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
