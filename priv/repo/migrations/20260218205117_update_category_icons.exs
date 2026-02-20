defmodule WaziBet.Repo.Migrations.UpdateCategoryIcons do
  use Ecto.Migration

  alias WaziBet.Repo
  alias WaziBet.Sport.SportsCategory

  def up do
    # Use valid heroicons (outline 24px versions)
    icon_map = %{
      "Football" => "hero-trophy",
      "Soccer" => "hero-trophy",
      "Basketball" => "hero-fire",
      "Tennis" => "hero-star",
      "Baseball" => "hero-bolt",
      "Hockey" => "hero-snowflake",
      "Rugby" => "hero-users",
      "Cricket" => "hero-flag",
      "Golf" => "hero-sun",
      "Boxing" => "hero-hand-raised",
      "MMA" => "hero-hand-raised",
      "Formula 1" => "hero-currency-dollar",
      "Racing" => "hero-currency-dollar",
      "Esports" => "hero-computer-desktop",
      "Volleyball" => "hero-globe",
      "Handball" => "hero-hand",
      "Ice Hockey" => "hero-snowflake"
    }

    # Update each category with appropriate icon
    Repo.all(SportsCategory)
    |> Enum.each(fn category ->
      icon = Map.get(icon_map, category.name, "hero-trophy")

      Ecto.Changeset.change(category, icon: icon)
      |> Repo.update!()
    end)
  end

  def down do
    # Reset all icons to default
    Repo.update_all(SportsCategory, set: [icon: "hero-trophy"])
  end
end
