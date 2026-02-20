# Script for populating the database with sample data
# Run with: mix run priv/repo/seeds.exs

alias WaziBet.Repo
alias WaziBet.Accounts.{User, Role, Permission}
alias WaziBet.Sport.{SportsCategory, Team, Game}
alias WaziBet.Bets.{Outcome, OddsCalculator}

import Ecto.Query

IO.puts("Seeding database...")

# Helper function to create users with passwords and profile info
create_user = fn email, first_name, last_name, msisdn, balance, password, confirmed_at ->
  %User{}
  |> User.registration_changeset(%{
    email: email,
    first_name: first_name,
    last_name: last_name,
    msisdn: msisdn,
    balance: balance,
    password: password
  })
  |> Ecto.Changeset.put_change(:confirmed_at, confirmed_at)
  |> Repo.insert!()
end

# Helper function to create categories
create_category = fn name ->
  %SportsCategory{}
  |> SportsCategory.changeset(%{
    name: name
  })
  |> Repo.insert!()
end

# Helper function to create teams
create_team = fn name, attack, defense, category ->
  %Team{}
  |> Team.changeset(%{
    name: name,
    attack_rating: attack,
    defense_rating: defense,
    category_id: category.id
  })
  |> Repo.insert!()
end

# Helper function to create game with outcomes
create_game = fn home_team, away_team, category, starts_at ->
  game =
    %Game{}
    |> Game.create_changeset(%{
      home_team_id: home_team.id,
      away_team_id: away_team.id,
      category_id: category.id,
      starts_at: starts_at,
      status: :scheduled
    })
    |> Repo.insert!()

  # Create outcomes directly using OddsCalculator
  alias WaziBet.Bets.OddsCalculator

  fair_odds =
    OddsCalculator.calculate_fair_odds(
      home_team.attack_rating,
      home_team.defense_rating,
      away_team.attack_rating,
      away_team.defense_rating
    )

  # Calculate probabilities from odds
  home_prob = OddsCalculator.odds_to_probability(fair_odds.home)
  draw_prob = OddsCalculator.odds_to_probability(fair_odds.draw)
  away_prob = OddsCalculator.odds_to_probability(fair_odds.away)

  # Create outcomes directly linked to game
  [
    %{label: :home, odds: fair_odds.home, prob: home_prob},
    %{label: :draw, odds: fair_odds.draw, prob: draw_prob},
    %{label: :away, odds: fair_odds.away, prob: away_prob}
  ]
  |> Enum.each(fn outcome_data ->
    %Outcome{}
    |> Outcome.changeset(%{
      game_id: game.id,
      label: outcome_data.label,
      odds: outcome_data.odds,
      probability: outcome_data.prob,
      status: :open
    })
    |> Repo.insert!()
  end)

  game
end

IO.puts("\n=== Creating/Updating Users ===")

# Create test users with passwords (all confirmed)
confirmed_at = DateTime.utc_now() |> DateTime.truncate(:second)

users = [
  %{
    email: "player1@example.com",
    first_name: "Player",
    last_name: "One",
    msisdn: "+254712345001",
    balance: "1000.00",
    password: "password123456"
  },
  %{
    email: "player2@example.com",
    first_name: "Player",
    last_name: "Two",
    msisdn: "+254712345002",
    balance: "500.00",
    password: "password123456"
  },
  %{
    email: "player3@example.com",
    first_name: "Player",
    last_name: "Three",
    msisdn: "+254712345003",
    balance: "2000.00",
    password: "password123456"
  },
  %{
    email: "admin@example.com",
    first_name: "Admin",
    last_name: "User",
    msisdn: "+254712345000",
    balance: "0.00",
    password: "admin_password123"
  }
]

created_users =
  Enum.map(users, fn user_data ->
    # Check if user already exists
    case Repo.get_by(User, email: user_data.email) do
      nil ->
        # Create new user
        user =
          create_user.(
            user_data.email,
            user_data.first_name,
            user_data.last_name,
            user_data.msisdn,
            user_data.balance,
            user_data.password,
            confirmed_at
          )

        IO.puts(
          "  Created user: #{user.email} (#{user.first_name} #{user.last_name}, #{user.msisdn})"
        )

        user

      existing_user ->
        # Update existing user with all fields
        {:ok, user} =
          existing_user
          |> User.registration_changeset(%{
            password: user_data.password,
            first_name: user_data.first_name,
            last_name: user_data.last_name,
            msisdn: user_data.msisdn
          })
          |> Ecto.Changeset.put_change(:confirmed_at, confirmed_at)
          |> Repo.update()

        IO.puts(
          "  Updated user: #{user.email} (#{user.first_name} #{user.last_name}, #{user.msisdn})"
        )

        user
    end
  end)

IO.puts("\n=== Creating Roles ===")

# Create roles (slugs auto-generated from role names)
roles_data = [
  %{role: "user"},
  %{role: "admin"}
]

roles =
  Enum.map(roles_data, fn role_data ->
    %Role{}
    |> Role.changeset(role_data)
    |> Repo.insert!()
    |> tap(fn role -> IO.puts("  Created role: #{role.role}") end)
  end)

# Associate users with roles
[player1, player2, player3, admin] = created_users
[user_role, admin_role] = roles

# Assign admin role to admin user
Repo.insert_all("user_roles", [
  %{
    user_id: admin.id,
    role_id: admin_role.id,
    inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
    updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
  }
])

IO.puts("  Assigned admin role to #{admin.email}")

# Assign user role to players
Enum.each([player1, player2, player3], fn player ->
  Repo.insert_all("user_roles", [
    %{
      user_id: player.id,
      role_id: user_role.id,
      inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
      updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    }
  ])

  IO.puts("  Assigned user role to #{player.email}")
end)

IO.puts("\n=== Creating Permissions ===")

# Create permissions (slugs auto-generated from permission names)
# User permissions (view_games removed - games are now public)
user_permissions = [
  %{permission: "place_bets"},
  %{permission: "cancel_bets"},
  %{permission: "view_bet_history"},
  %{permission: "view_winnings_losses"}
]

# Admin permissions
admin_permissions = [
  %{permission: "create_users"},
  %{permission: "assign_roles"},
  %{permission: "grant_revoke_admin_access"},
  %{permission: "view_users"},
  %{permission: "view_user_games"},
  %{permission: "soft_delete_users"},
  %{permission: "view_profits_from_losses"},
  %{permission: "configure_games"}
]

permissions_data = user_permissions ++ admin_permissions

permissions =
  Enum.map(permissions_data, fn perm_data ->
    %Permission{}
    |> Permission.changeset(perm_data)
    |> Repo.insert!()
    |> tap(fn perm -> IO.puts("  Created permission: #{perm.permission}") end)
  end)

# Split permissions into user and admin lists (4 user permissions, 8 admin permissions)
user_perms = Enum.take(permissions, 4)
admin_perms = Enum.drop(permissions, 4)

# Assign all admin permissions to admin role
Enum.each(admin_perms, fn perm ->
  Repo.insert_all("role_permissions", [
    %{
      role_id: admin_role.id,
      permission_id: perm.id,
      inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
      updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    }
  ])
end)

IO.puts("  Assigned #{length(admin_perms)} permissions to admin role")

# Assign user permissions to user role
Enum.each(user_perms, fn perm ->
  Repo.insert_all("role_permissions", [
    %{
      role_id: user_role.id,
      permission_id: perm.id,
      inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
      updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    }
  ])
end)

IO.puts("  Assigned #{length(user_perms)} permissions to user role")

IO.puts("\n=== Creating Categories ===")

# Create sports categories
categories_data = [
  %{name: "Football"},
  %{name: "Basketball"},
  %{name: "Tennis"},
  %{name: "Rugby"}
]

categories =
  Enum.map(categories_data, fn category_data ->
    category = create_category.(category_data.name)
    IO.puts("  Created category: #{category.name}")
    category
  end)

IO.puts("\n=== Creating Teams ===")

# Create teams for each sports category (2 teams per sport)
teams_by_category = %{
  "Football" => [
    %{name: "Manchester City", attack: 88, defense: 70},
    %{name: "Real Madrid", attack: 89, defense: 86}
  ],
  "Basketball" => [
    %{name: "LA Lakers", attack: 90, defense: 75},
    %{name: "Chicago Bulls", attack: 85, defense: 80}
  ],
  "Tennis" => [
    %{name: "Federer", attack: 92, defense: 88},
    %{name: "Nadal", attack: 90, defense: 90}
  ],
  "Rugby" => [
    %{name: "All Blacks", attack: 87, defense: 85},
    %{name: "Springboks", attack: 85, defense: 87}
  ]
}

all_teams =
  Enum.flat_map(categories, fn category ->
    teams = Map.get(teams_by_category, category.name, [])

    Enum.map(teams, fn team_data ->
      team = create_team.(team_data.name, team_data.attack, team_data.defense, category)
      IO.puts("  Created team: #{team.name} (A:#{team.attack_rating}/D:#{team.defense_rating})")
      {category.id, team}
    end)
  end)
  |> Enum.group_by(fn {category_id, _} -> category_id end, fn {_, team} -> team end)

IO.puts("\n=== Creating Scheduled Games ===")

# Create scheduled games
now = DateTime.utc_now()

scheduled_games =
  categories
  |> Enum.take(2)
  |> Enum.flat_map(fn category ->
    teams = Map.get(all_teams, category.id, [])

    if length(teams) >= 2 do
      # Create 1 game per category (2 teams only)
      home = Enum.at(teams, 0)
      away = Enum.at(teams, 1)
      starts_at = DateTime.add(now, 3600, :second)
      game = create_game.(home, away, category, starts_at)
      IO.puts("  Created game: #{home.name} vs #{away.name} at #{starts_at}")
      [game]
    else
      []
    end
  end)

IO.puts("\n=== Creating Ready-to-Play Games ===")

# Create games that are ready to start immediately (for testing)
ready_games =
  categories
  |> Enum.take(2)
  |> Enum.flat_map(fn category ->
    teams = Map.get(all_teams, category.id, [])

    if length(teams) >= 2 do
      home = Enum.at(teams, 0)
      away = Enum.at(teams, 1)

      [{home, away}]
      |> Enum.map(fn {home, away} ->
        # Create game that started 1 minute ago
        starts_at = DateTime.add(now, -60, :second)

        game =
          %Game{}
          |> Game.create_changeset(%{
            home_team_id: home.id,
            away_team_id: away.id,
            category_id: category.id,
            starts_at: starts_at,
            status: :scheduled
          })
          |> Repo.insert!()

        # Create outcomes directly using OddsCalculator
        fair_odds =
          OddsCalculator.calculate_fair_odds(
            home.attack_rating,
            home.defense_rating,
            away.attack_rating,
            away.defense_rating
          )

        home_prob = OddsCalculator.odds_to_probability(fair_odds.home)
        draw_prob = OddsCalculator.odds_to_probability(fair_odds.draw)
        away_prob = OddsCalculator.odds_to_probability(fair_odds.away)

        [
          %{label: :home, odds: fair_odds.home, prob: home_prob},
          %{label: :draw, odds: fair_odds.draw, prob: draw_prob},
          %{label: :away, odds: fair_odds.away, prob: away_prob}
        ]
        |> Enum.each(fn outcome_data ->
          %Outcome{}
          |> Outcome.changeset(%{
            game_id: game.id,
            label: outcome_data.label,
            odds: outcome_data.odds,
            probability: outcome_data.prob,
            status: :open
          })
          |> Repo.insert!()
        end)

        IO.puts("  Created ready game: #{home.name} vs #{away.name}")
        game
      end)
    else
      []
    end
  end)

IO.puts("\n=== Seed Data Summary ===")
IO.puts("  Users: #{length(created_users)}")
IO.puts("  Roles: #{length(roles)}")
IO.puts("  Permissions: #{length(permissions)}")
IO.puts("  Categories: #{length(categories)}")
IO.puts("  Teams: #{Enum.sum(Enum.map(all_teams, fn {_, teams} -> length(teams) end))}")
IO.puts("  Scheduled Games: #{length(scheduled_games)}")
IO.puts("  Ready Games: #{length(ready_games)}")
IO.puts("\nSeed completed successfully!")
IO.puts("\nYou can now:")
IO.puts("  - Start games using GameSupervisor.start_game(game)")
IO.puts("  - Place bets using WaziBet.Bets.place_betslip/3")
IO.puts("  - Watch games simulate in real-time")
