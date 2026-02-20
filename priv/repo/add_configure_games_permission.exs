# Script to add configure-games permission
alias WaziBet.{Repo, Accounts}

# Create configure_games permission if it doesn't exist
permission = Repo.get_by(Accounts.Permission, slug: "configure-games")

if permission do
  IO.puts("✓ configure-games permission already exists")
else
  {:ok, perm} =
    %Accounts.Permission{}
    |> Accounts.Permission.changeset(%{permission: "configure_games"})
    |> Repo.insert()

  IO.puts("✓ Created permission: #{perm.permission} → #{perm.slug}")

  # Assign to admin role
  admin_role = Repo.get_by(Accounts.Role, slug: "admin")

  if admin_role do
    Repo.insert_all("role_permissions", [
      %{
        role_id: admin_role.id,
        permission_id: perm.id,
        inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
        updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      }
    ])

    IO.puts("✓ Assigned configure-games to admin role")
  end
end
