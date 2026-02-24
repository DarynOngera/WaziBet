defmodule WaziBet.Accounts.Permission do
  use Ecto.Schema
  import Ecto.Changeset

  alias WaziBet.Accounts.Role

  schema "permissions" do
    field :permission, :string
    field :slug, :string

    many_to_many :roles, Role, join_through: "role_permissions"

    timestamps()
  end

  def changeset(permission, attrs) do
    permission
    |> cast(attrs, [:permission])
    |> validate_required([:permission])
    |> generate_slug()
  end

  defp generate_slug(changeset) do
    case get_change(changeset, :permission) do
      nil ->
        changeset

      permission_str ->
        put_change(changeset, :slug, Slug.slugify(permission_str))
    end
  end
end
