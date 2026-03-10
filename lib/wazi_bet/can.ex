defmodule WaziBet.Can do
  @moduledoc """
  Authorization module using Canada for declarative permission checks.
  Permissions are still stored in the database but checked via this module.
  """

  alias WaziBet.Accounts.User

  @permission_slugs [
    "place-bets",
    "cancel-bets",
    "view-bet-history",
    "view-winnings-losses",
    "create-users",
    "assign-roles",
    "grant-revoke-admin-access",
    "view-users",
    "view-user-games",
    "soft-delete-users",
    "view-profits-from-losses",
    "configure-games"
  ]

  @permission_slug_to_action Map.new(@permission_slugs, fn slug ->
                               {slug, slug |> String.replace("-", "_") |> String.to_atom()}
                             end)
  @permission_action_to_slug Map.new(@permission_slug_to_action, fn {slug, action} ->
                               {action, slug}
                             end)

  defmacro __using__(_opts) do
    quote do
      import unquote(__MODULE__), only: [can?: 2]
    end
  end

  @doc """
  Checks if a user has permission to perform an action.
  This is a convenience function that wraps Canada.Can implementation.
  """
  def can?(%User{} = user, action) when is_atom(action) do
    Canada.Can.can?(user, action, :any)
  end

  def can?(%User{} = user, {action, resource}) when is_atom(action) do
    Canada.Can.can?(user, action, resource)
  end

  def can?(%{} = user_attrs, action) when is_atom(action) do
    struct(User, user_attrs) |> can?(action)
  end

  def can?(%{} = user_attrs, {action, resource}) when is_atom(action) do
    struct(User, user_attrs) |> can?({action, resource})
  end

  @doc """
  Checks if a user has permission for the given slug.
  """
  def can_slug?(%User{} = user, slug) when is_binary(slug) do
    case slug_to_action(slug) do
      action when is_atom(action) -> can?(user, action)
      _ -> false
    end
  end

  def can_slug?(%{} = user_attrs, slug) when is_binary(slug) do
    struct(User, user_attrs) |> can_slug?(slug)
  end

  @doc """
  Checks if any of the given permissions are granted.
  """
  def can_any?(%User{} = user, actions) when is_list(actions) do
    Enum.any?(actions, &can?(user, &1))
  end

  def can_any?(%{} = user_attrs, actions) when is_list(actions) do
    Enum.any?(actions, &can?(user_attrs, &1))
  end

  @doc """
  Checks if any permission slugs are granted.
  """
  def can_any_slug?(%User{} = user, slugs) when is_list(slugs) do
    Enum.any?(slugs, &can_slug?(user, &1))
  end

  def can_any_slug?(%{} = user_attrs, slugs) when is_list(slugs) do
    Enum.any?(slugs, &can_slug?(user_attrs, &1))
  end

  @doc """
  Converts a permission slug to its corresponding atom action.
  """
  def slug_to_action(slug) when is_binary(slug) do
    Map.get(@permission_slug_to_action, slug)
  end

  def slug_to_action(slug) when is_atom(slug) do
    if Map.has_key?(@permission_action_to_slug, slug), do: slug, else: nil
  end

  @doc """
  Converts an action atom to its permission slug.
  """
  def action_to_slug(action) when is_atom(action) do
    Map.get(@permission_action_to_slug, action)
  end
end

defimpl Canada.Can, for: WaziBet.Accounts.User do
  alias WaziBet.Accounts.User
  alias WaziBet.Can

  def can?(%User{id: user_id}, action, :any) when is_atom(action) do
    user_permissions = WaziBet.Accounts.get_user_permission_slugs(user_id)

    case Can.action_to_slug(action) do
      slug when is_binary(slug) -> slug in user_permissions
      _ -> false
    end
  end

  def can?(%User{id: _user_id}, _action, _resource) do
    false
  end
end
