defmodule WaziBet.Accounts do
  @moduledoc """
  The Accounts context.

  This module handles:
  - User management (registration, authentication, settings)
  - Balance operations
  - Role and permission management
  """

  import Ecto.Query, warn: false
  alias WaziBet.Repo
  alias WaziBet.Accounts.{User, UserToken, UserNotifier, Role, Permission}

  ## Database getters

  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)
    if User.valid_password?(user, password), do: user
  end

  def get_user!(id), do: Repo.get!(User, id)

  def get_user_with_roles!(id) do
    User
    |> Repo.get!(id)
    |> Repo.preload(roles: [:permissions])
  end

  ## User registration

  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, user} ->
        case Repo.get_by(Role, slug: "user") do
          nil ->
            {:ok, user}

          role ->
            assign_role_to_user(user.id, role.id)
            {:ok, user}
        end

      error ->
        error
    end
  end

  def create_user(attrs) do
    register_user(attrs)
  end

  def change_user_email(user, attrs \\ %{}, opts \\ []) do
    User.email_changeset(user, attrs, opts)
  end

  def update_user_email(user, token) do
    context = "change:#{user.email}"

    Repo.transact(fn ->
      with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
           %UserToken{sent_to: email} <- Repo.one(query),
           {:ok, user} <- Repo.update(User.email_changeset(user, %{email: email})),
           {_count, _result} <-
             Repo.delete_all(from(UserToken, where: [user_id: ^user.id, context: ^context])) do
        {:ok, user}
      else
        _ -> {:error, :transaction_aborted}
      end
    end)
  end

  def change_user_password(user, attrs \\ %{}, opts \\ []) do
    User.password_changeset(user, attrs, opts)
  end

  def update_user_password(user, attrs) do
    user
    |> User.password_changeset(attrs)
    |> update_user_and_delete_all_tokens()
  end

  ## Session

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
         {user, _token} <- Repo.one(query) do
      user
    else
      _ -> nil
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

  def deliver_user_update_email_instructions(%User{} = user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "change:#{current_email}")

    Repo.insert!(user_token)
    UserNotifier.deliver_update_email_instructions(user, update_email_url_fun.(encoded_token))
  end

  def deliver_login_instructions(%User{} = user, magic_link_url_fun)
      when is_function(magic_link_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "login")
    Repo.insert!(user_token)
    UserNotifier.deliver_login_instructions(user, magic_link_url_fun.(encoded_token))
  end

  def delete_user_session_token(token) do
    Repo.delete_all(from(UserToken, where: [token: ^token, context: "session"]))
    :ok
  end

  ## Balance Operations

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

  def update_user_balance(user, new_balance) do
    update_balance(user, new_balance)
  end

  def lock_user_for_update(user_id) do
    from(u in User, where: u.id == ^user_id, lock: "FOR UPDATE")
    |> Repo.one()
  end

  def create_role(role, attrs) do
    role
    |> Role.changeset(attrs)
    |> Repo.insert()
  end

  ## Permission Checking

  def user_has_permission?(user_id, permission_slug) when is_binary(permission_slug) do
    permission_slug in get_user_permission_slugs(user_id)
  end

  def get_user_permission_slugs(user_id) do
    Repo.all(
      from p in Permission,
        join: rp in "role_permissions",
        on: rp.permission_id == p.id,
        join: r in Role,
        on: r.id == rp.role_id,
        join: ur in "user_roles",
        on: ur.role_id == r.id,
        where: ur.user_id == ^user_id,
        select: p.slug,
        distinct: true
    )
  end

  def get_user_with_permissions(user_id) do
    User
    |> Repo.get(user_id)
    |> Repo.preload(roles: [:permissions])
  end

  def assign_role_to_user(user_id, role_id) do
    Repo.insert_all("user_roles", [
      %{
        user_id: user_id,
        role_id: role_id,
        inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
        updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      }
    ])
  end

  def remove_role_from_user(user_id, role_id) do
    from(ur in "user_roles",
      where: ur.user_id == ^user_id and ur.role_id == ^role_id
    )
    |> Repo.delete_all()
  end

  def list_roles_with_permissions do
    Role
    |> Repo.all()
    |> Repo.preload(:permissions)
  end

  def list_users(opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    page_size = Keyword.get(opts, :page_size, 10)

    User
    |> where([u], is_nil(u.deleted_at))
    |> order_by([u], u.id)
    |> limit(^page_size)
    |> offset(^((page - 1) * page_size))
    |> Repo.all()
    |> Repo.preload(:roles)
  end

  def count_users do
    User
    |> where([u], is_nil(u.deleted_at))
    |> Repo.aggregate(:count, :id)
  end

  def get_user_with_betslips!(id) do
    User
    |> Repo.get!(id)
    |> Repo.preload(betslips: [:selections], roles: [:permissions])
  end

  def soft_delete_user(user) do
    user
    |> User.soft_delete_changeset()
    |> Repo.update()
  end

  def list_roles do
    Repo.all(Role)
  end

  def get_role!(id), do: Repo.get!(Role, id)

  def user_has_role?(user_id, role_slug) do
    from(r in Role,
      join: ur in "user_roles",
      on: ur.role_id == r.id,
      where: ur.user_id == ^user_id and r.slug == ^role_slug,
      select: count(r.id)
    )
    |> Repo.one() > 0
  end

  ## Permission Management

  def list_permissions do
    Permission
    |> order_by([p], p.slug)
    |> Repo.all()
  end

  def get_permission!(id), do: Repo.get!(Permission, id)

  def create_permission(attrs \\ %{}) do
    %Permission{}
    |> Permission.changeset(attrs)
    |> Repo.insert()
  end

  def change_permission(permission \\ %Permission{}, attrs \\ %{}) do
    Permission.changeset(permission, attrs)
  end

  def delete_permission(%Permission{} = permission) do
    # Check if permission is assigned to any roles
    role_count =
      from(rp in "role_permissions",
        where: rp.permission_id == ^permission.id,
        select: count(rp.id)
      )
      |> Repo.one()

    if role_count > 0 do
      {:error, :permission_in_use}
    else
      Repo.delete(permission)
    end
  end

  def delete_role(%Role{} = role) do
    if role.slug in ["admin", "user"] do
      {:error, :protected_role}
    else
      user_count =
        from(ur in "user_roles",
          where: ur.role_id == ^role.id,
          select: count(ur.role_id)
        )
        |> Repo.one()

      if user_count > 0 do
        {:error, :role_in_use}
      else
        case Repo.transact(fn ->
               from(rp in "role_permissions", where: rp.role_id == ^role.id) |> Repo.delete_all()
               Repo.delete(role)
             end) do
          {:ok, {:ok, deleted_role}} -> {:ok, deleted_role}
          {:ok, {:error, _changeset}} -> {:error, :delete_failed}
          {:error, _reason} -> {:error, :delete_failed}
        end
      end
    end
  end

  ## Role Permission Management

  def get_role_with_permissions!(id) do
    Role
    |> Repo.get!(id)
    |> Repo.preload(:permissions)
  end

  def assign_permission_to_role(role_id, permission_id) do
    Repo.insert_all("role_permissions", [
      %{
        role_id: role_id,
        permission_id: permission_id,
        inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
        updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      }
    ])
  end

  def remove_permission_from_role(role_id, permission_id) do
    from(rp in "role_permissions",
      where: rp.role_id == ^role_id and rp.permission_id == ^permission_id
    )
    |> Repo.delete_all()
  end

  def create_role_with_permissions(attrs, permission_ids) do
    Repo.transact(fn ->
      with {:ok, role} <- create_role(%Role{}, attrs),
           :ok <- assign_permissions_to_role(role.id, permission_ids) do
        {:ok, Repo.preload(role, :permissions)}
      else
        {:error, changeset} -> {:error, changeset}
      end
    end)
  end

  defp assign_permissions_to_role(_role_id, []), do: :ok

  defp assign_permissions_to_role(role_id, permission_ids) do
    Enum.each(permission_ids, fn permission_id ->
      assign_permission_to_role(role_id, permission_id)
    end)

    :ok
  end

  ## Token helper

  defp update_user_and_delete_all_tokens(changeset) do
    Repo.transact(fn ->
      with {:ok, user} <- Repo.update(changeset) do
        tokens_to_expire = Repo.all(from(t in UserToken, where: t.user_id == ^user.id))

        Repo.delete_all(from(t in UserToken, where: t.id in ^Enum.map(tokens_to_expire, & &1.id)))

        {:ok, {user, tokens_to_expire}}
      end
    end)
  end

  ## Settings

  @doc """
  Checks whether the user is in sudo mode.
  """
  def sudo_mode?(user, minutes \\ -20)

  def sudo_mode?(%User{authenticated_at: ts}, minutes) when is_struct(ts, DateTime) do
    DateTime.after?(ts, DateTime.utc_now() |> DateTime.add(minutes, :minute))
  end

  def sudo_mode?(_user, _minutes), do: false
end
