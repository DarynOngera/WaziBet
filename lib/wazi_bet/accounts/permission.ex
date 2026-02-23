defmodule WaziBet.Accounts.Permission do
  use Ecto.Schema
  import Ecto.Changeset
  alias WaziBet.Accounts.Role

  schema "permissions" do
    field :name, :string
    field :description, :string

    many_to_many :roles, Role, join_through: "roles_permissions"

    timestamps(type: :utc_datetime)
  end

  
  def changeset(permission, attrs) do
    permission
    |> cast(attrs, [:name, :description])
    |> validate_required([:name, :description])
    |> unique_constraint(:name)
  end
end
