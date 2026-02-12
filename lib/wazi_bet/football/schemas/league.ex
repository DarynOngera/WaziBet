defmodule WaziBet.Football.League do
  use Ecto.Schema
  import Ecto.Changeset

  alias WaziBet.Football.{Team, Game}

  schema "leagues" do
    field :name, :string
    field :country, :string
    field :season, :string

    has_many :teams, Team
    has_many :games, Game

    timestamps()
  end

  def changeset(league, attrs) do
    league
    |> cast(attrs, [:name, :country, :season])
    |> validate_required([:name, :country, :season])
    |> validate_length(:name, min: 2, max: 100)
    |> validate_length(:country, min: 2, max: 100)
    |> validate_season_format()
  end

  defp validate_season_format(changeset) do
    changeset
    |> validate_format(:season, ~r/^\d{4}\/\d{4}$|^\d{4}$/,
      message: "must be in format YYYY or YYYY/YYYY"
    )
  end
end
