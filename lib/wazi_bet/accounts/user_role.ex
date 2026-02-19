defmodule WaziBet.Accounts.UserRole do
  use Ecto.Schema
  import Ecto.Changeset

  alias WaziBet.Accounts.User
  alias WaziBet.Accounts.Role


  @primary_key false
  schema "users_roles" do
    belongs_to :user, User
    belongs_to :role, Role

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user_role, attrs) do
    user_role
    |> cast(attrs, [:user_id, :role_id])
    |> validate_required([:user_id, :role_id])
  end
end
