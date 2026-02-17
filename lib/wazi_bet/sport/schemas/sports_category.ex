defmodule WaziBet.Sport.SportsCategory do
  use Ecto.Schema
  import Ecto.Changeset

  alias WaziBet.Sport.{Team, Game}

  schema "sports_categories" do
    field :name, :string

    has_many :teams, Team, foreign_key: :category_id
    has_many :games, Game, foreign_key: :category_id

    timestamps()
  end

  def changeset(categories, attrs) do
    categories
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> validate_length(:name, min: 2, max: 100)
  end
end
