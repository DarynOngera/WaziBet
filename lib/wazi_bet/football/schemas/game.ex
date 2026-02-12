defmodule WaziBet.Football.Game do 
  use Ecto.Schema
  import Ecto.Changeset 

  alias WaziBet.Football.{League, Team, GameEvent}
  alias WaziBet.Bets.Market 

  @status [:scheduled, :live, :finished]

  schema "games" do
    field :status, Ecto.Enum, values: @status, default: :scheduled
    field :minute, :integer, default: 0
    field :home_score, :integer, default: 0 
    field :away_score, :integer, default: 0 
    field :starts_at, :utc_datetime

    belongs_to :league, League
    belongs_to :home_team, Team
    belongs_to :away_team, Team

    has_many :events, GameEvent 
    has_many :markets, Market

    timestamps()
  end

  def create_changeset(game, attrs) do 
    game 
    |> cast(attrs, [:starts_at, :league_id, :home_team_id, :away_team_id])
    |> validate_required(:starts_at, :league_id, :home_team)
    |> validate_teams_differ()
    |> foreign_key_constraint(:home_team_id)
    |> foreign_key_contraint(:away_team_id)
    |> check_contraint(:home_team_id, name: :teams_must_differ)
  end

  def status_changeset(game, status) when status in @status do
    change(game, status: status)
  end

  defp validate_teams_differ(changeset) do
    home_team = get_field(changeset, :home_team_id)
    away_team = get_field(changeset, :away_team_id)

    if home_team && away_team && home_team == away_team do
      add_error(changeset, :away_team_id, "Must be different teams")
    else
      changeset
    end
  end
end
