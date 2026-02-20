# Script to display admin user credentials
# Run with: mix run priv/repo/show_admin.exs

alias WaziBet.Repo
alias WaziBet.Accounts.{User, Role}

import Ecto.Query

IO.puts("\n=== Admin User Credentials ===\n")

# Find admin role
admin_role = Repo.get_by(Role, slug: "admin")

if admin_role do
  # Find users with admin role
  admin_users =
    from(u in User,
      join: ur in "user_roles",
      on: ur.user_id == u.id,
      where: ur.role_id == ^admin_role.id,
      where: is_nil(u.deleted_at),
      select: u
    )
    |> Repo.all()

  if admin_users != [] do
    Enum.each(admin_users, fn user ->
      IO.puts("Email:    #{user.email}")
      IO.puts("Password: admin_password123")
      IO.puts("Name:     #{user.first_name} #{user.last_name}")
      IO.puts("Phone:    #{user.msisdn}")
      IO.puts("")
    end)

    IO.puts("✓ Admin user(s) found in database")
  else
    IO.puts("✗ No admin users found")
    IO.puts("\nTo create an admin user, run:")
    IO.puts("  mix run priv/repo/seeds.exs")
  end
else
  IO.puts("✗ Admin role not found")
  IO.puts("\nTo setup the database with roles and permissions, run:")
  IO.puts("  mix ecto.reset")
end
