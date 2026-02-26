defmodule WaziBetWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use WaziBetWeb, :html

  import WaziBetWeb.CoreComponents, only: [icon: 1, flash: 1, show: 1, hide: 1]

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.
  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true

  attr :categories, :list, default: []

  attr :user_permissions, :list,
    default: [],
    doc: "list of user permission slugs for admin layout"

  attr :is_superuser, :boolean,
    default: false,
    doc: "whether the user is a superuser"

  attr :current_path, :string,
    default: "",
    doc: "current request path for active menu highlighting"

  def app(assigns) do
    ~H"""
    <header class="navbar bg-base-200 border-b border-base-300 sticky top-0 z-50">
      <div class="navbar-start gap-2">
        <.link href={~p"/"} class="btn btn-ghost text-xl font-bold tracking-wider">
          <span class="text-primary">WAZI</span><span class="text-secondary">BET</span>
        </.link>
        <%!-- Category Icons --%>
        <%= if length(@categories) > 0 do %>
          <div class="hidden md:flex items-center gap-1 border-l-2 border-base-300 pl-3">
            <%= for category <- @categories do %>
              <.link
                href={~p"/?category=#{category.id}"}
                class="btn btn-ghost btn-sm tooltip"
                data-tip={category.name}
              >
                <.icon name={category.icon} class="w-5 h-5" />
              </.link>
            <% end %>
          </div>
        <% end %>
      </div>
      <div>
        <ul class="flex items-center gap-2">
          <%= if @current_scope do %>
            <%!-- Balance Display --%>
            <li>
              <.link href={~p"/account"} class="btn btn-sm btn-ghost">
                <.icon name="hero-currency-dollar" class="w-4 h-4 text-success" />
                <span class="font-mono text-sm">
                  ${Decimal.round(@current_scope.user.balance, 2)}
                </span>
              </.link>
            </li>
            <li class="hidden md:block">
              <span class="text-base-content/50">|</span>
            </li>
            <li class="hidden sm:block">
              <span class="text-base-content/70 font-mono text-sm">{@current_scope.user.email}</span>
            </li>
          <% end %>
        </ul>
      </div>
      <div class="navbar-end">
        <ul class="menu menu-horizontal items-center gap-2">
          <%= if @current_scope do %>
            <%!-- Balance Display --%>
            <li>
              <.link href={~p"/account"} class="btn btn-sm btn-ghost" title="My Account">
                <.icon name="hero-user-circle" class="w-4 h-4" />
              </.link>
            </li>
            <li>
              <.link href={~p"/betslip"} class="btn btn-sm btn-primary">
                <.icon name="hero-ticket" class="w-4 h-4" />
                <span class="hidden sm:inline">My Bets</span>
              </.link>
            </li>
            <li>
              <.link href={~p"/users/settings"} class="btn btn-sm btn-ghost">
                <.icon name="hero-cog-6-tooth" class="w-4 h-4" />
              </.link>
            </li>
            <li>
              <.link href={~p"/users/log-out"} method="delete" class="btn btn-sm btn-ghost text-error">
                <.icon name="hero-arrow-right-on-rectangle" class="w-4 h-4" />
              </.link>
            </li>
          <% else %>
            <li>
              <.link href={~p"/users/log-in"} class="btn btn-sm btn-primary">Log in</.link>
            </li>
            <li>
              <.link href={~p"/users/register"} class="btn btn-sm btn-secondary">Register</.link>
            </li>
          <% end %>
          <li>
            <.theme_toggle />
          </li>
        </ul>
      </div>
    </header>

    <main class="px-4 py-8 sm:px-6 lg:px-8 min-h-[calc(100vh-4rem)]">
      <div class="mx-auto max-w-6xl">
        {render_slot(@inner_block)}
      </div>
    </main>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end

  def has_permission?(permissions, slug) do
    slug in permissions
  end
end
