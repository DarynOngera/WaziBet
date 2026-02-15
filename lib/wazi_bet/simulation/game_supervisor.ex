defmodule WaziBet.Simulation.GameSupervisor do
  @moduledoc """
  DynamicSupervisor for managing GameServer processes.

  Each game gets its own GameServer process.
  """

  use DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @doc """
  Starts a new GameServer for the given game_id.
  """
  def start_game(game_id) do
    spec = %{
      id: WaziBet.Simulation.GameServer,
      start: {WaziBet.Simulation.GameServer, :start_link, [game_id]},
      restart: :transient
    }

    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  @doc """
  Stops a GameServer process.
  """
  def stop_game(game_pid) when is_pid(game_pid) do
    DynamicSupervisor.terminate_child(__MODULE__, game_pid)
  end

  @doc """
  Lists all running GameServer processes.
  """
  def running_games do
    DynamicSupervisor.which_children(__MODULE__)
    |> Enum.map(fn {_, pid, _, _} -> pid end)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(
      strategy: :one_for_one,
      max_restarts: 1000,
      max_seconds: 60
    )
  end
end
