defmodule WaziBet.Accounts do
  @moduledoc """
  User management and balance operations.
  """

  import Ecto.Query

  alias WaziBet.Accounts.User
  alias WaziBet.Accounts.Role
  alias WaziBet.Accounts.Permission
  alias WaziBet.Repo


  def get_user!(id) do
    Repo.get!(User, id)
  end

  def get_user_by_email(email) do
    Repo.get_by(User, email: email)
  end

  def get_user_by_email_and_password(email, password) do
    user = Repo.get_by(User, email: email)

    if user && User.valid_password?(user, password) do
      user
    else
      nil
    end
  end

  def update_balance(user, amount) do
    user
    |> User.balance_changeset(%{balance: amount})
    |> Repo.update()
  end

  def deduct_balance(user, amount) do
    new_balance = Decimal.sub(user.balance, amount)

    if Decimal.compare(new_balance, Decimal.new(0)) == :lt do
      {:error, :insufficient_balance}
    else
      update_balance(user, new_balance)
    end
  end

  def credit_balance(user, amount) do
    new_balance = Decimal.add(user.balance, amount)
    update_balance(user, new_balance)
  end

  def lock_user_for_update(user_id) do
    from(u in User, where: u.id == ^user_id, lock: "FOR UPDATE")
    |> Repo.one()
  end

  def get_role!(id), do: Repo.get!(Role, id)

def create_role(attrs \\ %{}) do
  %Role{}
  |> Role.changeset(attrs)
  |> Repo.insert()
end

def update_role(%Role{} = role, attrs) do
  role
  |> Role.changeset(attrs)
  |> Repo.update()
end

def list_permissions do
  Repo.all(Permission)
end

def get_permission!(id), do: Repo.get!(Permission, id)

def create_permission(attrs \\ %{}) do
  %Permission{}
  |> Permission.changeset(attrs)
  |> Repo.insert()
end

def update_permission(%Permission{} = permission, attrs) do
  permission
  |> Permission.changeset(attrs)
  |> Repo.update()
end


def add_role_to_user(user, role) do
  user
  |> Repo.preload(:roles)
  |> Ecto.Changeset.change()
  |> Ecto.Changeset.put_assoc(:roles, [role | user.roles])
  |> Repo.update()
end

def add_permission_to_role(role, permission) do
  role
  |> Repo.preload(:permissions)
  |> Ecto.Changeset.change()
  |> Ecto.Changeset.put_assoc(:permissions, [permission | role.permissions])
  |> Repo.update()
end

def change_user_registration(%User{} = user, attrs \\ %{}) do
  User.registration_changeset(user, attrs)
end

def register_user(attrs) do
  %User{}
  |> User.registration_changeset(attrs)
  |> Repo.insert()
end

#session management

def login_user_by_magic_link(token) do
  case Repo.get_by(User, magic_link_token: token) do
    nil -> {:error, :invalid_token}
    user -> {:ok, {user, []}}
  end
end

def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  def get_user_by_magic_link_token(token) do
    with {:ok, query} <- UserToken.verify_magic_link_token_query(token),
         {user, token} <- Repo.one(query) do
      user
    else
       -> nil
    end
  end

  def login_user_by_magic_link(token) do
    {:ok, query} = UserToken.verify_magic_link_token_query(token)

    case Repo.one(query) do
      {%User{confirmed_at: nil, hashed_password: hash}, _token} when not is_nil(hash) ->
        raise """
        magic link log in is not allowed for unconfirmed users with a password set!
        """

      {%User{confirmed_at: nil} = user, _token} ->
        user
        |> User.confirm_changeset()
        |> update_user_and_delete_all_tokens()

      {user, token} ->
        Repo.delete!(token)
        {:ok, {user, []}}

      nil ->
        {:error, :not_found}
    end
  end

end
