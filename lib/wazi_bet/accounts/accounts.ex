defmodule WaziBet.Accounts do
  @moduledoc """
  User management and balance operations.
  """

  import Ecto.Query

  alias WaziBet.Accounts.User
  alias WaziBet.Repo

  def create_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  def get_user!(id) do
    Repo.get!(User, id)
  end

  def get_user_by_email(email) do
    Repo.get_by(User, email: email)
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
end
