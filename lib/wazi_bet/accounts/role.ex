defmodule WaziBet.Accounts.Role do
  use Ecto.Schema
  import Ecto.Changeset

  alias WaziBet.Accounts.User
  alias WaziBet.Accounts.Permission

  schema "roles" do
    field :role, :string
    field :slug, :string


    many_to_many :users,User, join_through: "user_roles"
    many_to_many :permissions, Permission, join_through: "role_permissions"
    timestamps()
  end


  def changeset(role, attrs) do
    role
    |> cast(attrs, [:role])
    |> validate_required([:role])
    |> generate_slug()
  end

  def generate_slug(changeset) do
    case get_change(changeset, :role) do
      nil -> changeset
      role_str -> put_change(changeset, :slug, Slug.slugify(role_str))
    end
  end
end
