defmodule WaziBet.Repo do
  use Ecto.Repo,
    otp_app: :wazi_bet,
    adapter: Ecto.Adapters.Postgres
end
