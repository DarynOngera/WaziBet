defmodule WaziBet.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  alias WaziBet.Bets.Betslip

  @roles [:player, :admin]

  schema "users" do
    field :email, :string
    field :balance, :decimal, default: Decimal.new("0.00")
    field :role, Ecto.Enum, values: @roles, default: :player
    field :hashed_password, :string

    has_many :betslips, Betslip

    timestamps()
  end

  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :balance, :role, :hashed_password])
    |> validate_required([:email])
    |> validate_email()
    |> validate_balance()
    |> validate_inclusion(:role, @roles)
  end

  def balance_changeset(user, attrs) do
    user
    |> cast(attrs, [:balance])
    |> validate_required([:balance])
    |> validate_balance()
  end

  defp validate_email(changeset) do
    changeset
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must be a valid email")
    |> validate_length(:email, max: 160)
    |> unsafe_validate_unique(:email, WaziBet.Repo)
    |> unique_constraint(:email)
  end

  defp validate_balance(changeset) do
    changeset
    |> validate_number(:balance, greater_than_or_equal_to: 0)
    |> check_constraint(:balance, name: :balance_must_be_non_negative)
  end
end
