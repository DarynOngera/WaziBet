defmodule WaziBet.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  alias WaziBet.Bets.Betslip
  alias WaziBet.Accounts.Role

  @min_password_length 12
  @max_password_length 72

  schema "users" do
    field :email, :string
    field :first_name, :string
    field :last_name, :string
    field :msisdn, :string
    field :balance, :decimal, default: Decimal.new("1000.0")
    field :hashed_password, :string, redact: true
    field :deleted_at, :utc_datetime
    field :confirmed_at, :utc_datetime
    field :authenticated_at, :utc_datetime

    # Virtual fields
    field :password, :string, virtual: true, redact: true
    field :password_confirmation, :string, virtual: true, redact: true

    many_to_many :roles, Role, join_through: "user_roles"
    has_many :betslips, Betslip

    timestamps()
  end

 def registration_changeset(user, attrs, opts \\ []) do
  user
  |> cast(attrs, [
    :email,
    :password,
    :password_confirmation,
    :balance,
    :first_name,
    :last_name,
    :msisdn
  ])
  |> validate_required([
    :email,
    :password,
    :password_confirmation,
    :first_name,
    :last_name,
    :msisdn
  ])
  |> validate_email(opts)
  |> validate_password(opts)
  |> validate_confirmation(:password, message: "does not match password")
  |> validate_balance()
  |> validate_length(:first_name, max: 100)
  |> validate_length(:last_name, max: 100)
  |> validate_format(:msisdn, ~r/^\+?[0-9]+$/, message: "must be a valid phone number")
  |> unique_constraint(:email)

end

  defp validate_email(changeset, opts) do
    changeset
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> maybe_validate_unique_email(opts)
  end

  defp maybe_validate_unique_email(changeset, opts) do
    if Keyword.get(opts, :validate_email, true) do
      changeset
      |> unsafe_validate_unique(:email, WaziBet.Repo)
      |> unique_constraint(:email)
    else
      changeset
    end
  end

  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: @min_password_length, max: @max_password_length)
    |> maybe_hash_password(opts)
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      |> validate_length(:password, max: @max_password_length, count: :bytes)
      |> put_change(:hashed_password, Bcrypt.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  @doc """
  A user changeset for changing the email.

  It requires the email to be validated and checks for uniqueness.
  """
  def email_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email])
    |> validate_email(opts)
    |> case do
      %{changes: %{email: _}} = changeset -> changeset
      %{} = changeset -> add_error(changeset, :email, "did not change")
    end
  end

  def password_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:password])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_password(opts)
  end

  def confirm_changeset(user) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    change(user, confirmed_at: now)
  end

  def valid_password?(%WaziBet.Accounts.User{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end

  def validate_current_password(changeset, password) do
    if valid_password?(changeset.data, password) do
      changeset
    else
      add_error(changeset, :current_password, "is not valid")
    end
  end

  def balance_changeset(user, attrs) do
    user
    |> cast(attrs, [:balance])
    |> validate_required([:balance])
    |> validate_balance()
  end

  defp validate_balance(changeset) do
    changeset
    |> validate_number(:balance, greater_than_or_equal_to: 0)
    |> check_constraint(:balance, name: :balance_must_be_non_negative)
  end

  def confirmed?(%WaziBet.Accounts.User{confirmed_at: nil}), do: false
  def confirmed?(%WaziBet.Accounts.User{}), do: true
end
