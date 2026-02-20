defmodule WaziBet.Sport do
  import Ecto.Query

  alias WaziBet.Sport.{SportsCategory, Team, Game, GameEvent}
  alias WaziBet.Repo

  # Categories

  def list_categories do
    Repo.all(SportsCategory)
  end

  def create_category(attrs) do
    %SportsCategory{}
    |> SportsCategory.changeset(attrs)
    |> Repo.insert()
  end

  def get_category!(id) do
    Repo.get!(SportsCategory, id)
  end

  # Teams

  def list_teams(category_id) do
    Repo.all(from t in Team, where: t.category_id == ^category_id)
  end

  def create_team(attrs) do
    %Team{}
    |> Team.changeset(attrs)
    |> Repo.insert()
  end

  def get_team!(id) do
    Repo.get!(Team, id)
  end

  # Games

  def list_games(filters \\ []) do
    Game
    |> filter_games(filters)
    |> Repo.all()
  end

  def list_live_games do
    Repo.all(from g in Game, where: g.status == :live)
  end

  def create_game(attrs) do
    %Game{}
    |> Game.create_changeset(attrs)
    |> Repo.insert()
  end

  def get_game!(id) do
    Repo.get!(Game, id)
  end

  def get_game_with_teams!(id) do
    Repo.get!(Game, id)
    |> Repo.preload([:home_team, :away_team, :category])
  end

  def update_game_state(game, attrs) do
    game
    |> Game.simulation_changeset(attrs)
    |> Repo.update()
  end

  def transition_game_status(game, new_status) do
    game
    |> Game.status_changeset(new_status)
    |> Repo.update()
  end

  # Events

  def create_event(attrs) do
    %GameEvent{}
    |> GameEvent.changeset(attrs)
    |> Repo.insert()
  end

  def list_events(game_id) do
    Repo.all(
      from e in GameEvent,
        where: e.game_id == ^game_id,
        order_by: [asc: e.minute]
    )
  end

  def replay_events(game_id) do
    game_id
    |> list_events()
    |> Enum.reduce(%{home_score: 0, away_score: 0}, fn event, acc ->
      case event.result do
        :home_score -> %{acc | home_score: acc.home_score + 1}
        :away_score -> %{acc | away_score: acc.away_score + 1}
        :none -> acc
      end
    end)
  end

  # Private functions

  defp filter_games(query, []), do: query

  defp filter_games(query, [{:status, status} | rest]) do
    query
    |> where([g], g.status == ^status)
    |> filter_games(rest)
  end

  defp filter_games(query, [{:category_id, category_id} | rest]) do
    query
    |> where([g], g.category_id == ^category_id)
    |> filter_games(rest)
  end

  defp filter_games(query, [{:starts_after, datetime} | rest]) do
    query
    |> where([g], g.starts_at >= ^datetime)
    |> filter_games(rest)
  end

  defp filter_games(query, [_ | rest]) do
    filter_games(query, rest)
  end
end
