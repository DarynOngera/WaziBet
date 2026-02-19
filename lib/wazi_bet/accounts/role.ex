defmodule WaziBet.Accounts.Role do
  use Ecto.Schema
  import Ecto.Changeset

  alias WaziBet.Accounts.User
  alias WaziBet.Accounts.Permission

  schema "roles" do
    field :name, :string


    many_to_many :users,User, join_through: "users_roles"
    many_to_many :permissions, Permission, join_through: "roles_permissions"
    timestamps()
  end


  def changeset(role, attrs) do
    role
    |> cast(attrs, [:name])
    |> validate_required([:name])
  end
end
