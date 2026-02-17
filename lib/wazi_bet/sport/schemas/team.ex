defmodule WaziBet.Sport.Team do
  use Ecto.Schema
  import Ecto.Changeset

  alias WaziBet.Sport.{SportsCategory, Game}

  schema "teams" do
    field :name, :string
    field :attack_rating, :integer, default: 50
    field :defense_rating, :integer, default: 50

    belongs_to :category, SportsCategory

    has_many :home_games, Game, foreign_key: :home_team_id
    has_many :away_games, Game, foreign_key: :away_team_id

    timestamps()
  end

  def changeset(team, attrs) do
    team
    |> cast(attrs, [:name, :attack_rating, :defense_rating, :category_id])
    |> validate_required([:name, :category_id])
    |> validate_length(:name, min: 2, max: 100)
    |> validate_rating(:attack_rating)
    |> validate_rating(:defense_rating)
    |> foreign_key_constraint(:category_id)
    |> unique_constraint([:category_id, :name],
      name: :teams_category_id_name_index,
      message: "already exists in this category"
    )
    |> check_constraint(:attack_rating, name: :attack_rating_range)
    |> check_constraint(:defense_rating, name: :defense_rating_range)
  end

  defp validate_rating(changeset, field) do
    changeset
    |> validate_number(field,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 100
    )
  end
end
