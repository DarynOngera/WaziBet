defmodule WaziBet.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      WaziBetWeb.Telemetry,
      WaziBet.Repo,
      {DNSCluster, query: Application.get_env(:wazi_bet, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: WaziBet.PubSub},
      {Registry, keys: :unique, name: WaziBet.GameRegistry},
      WaziBet.Simulation.GameSupervisor,
      WaziBetWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: WaziBet.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    WaziBetWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
