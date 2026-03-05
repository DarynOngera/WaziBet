defmodule WaziBet.Mail.BetslipEmail do
  @moduledoc """
  Email constructor for betslip settlement notifications.
  Sends a win or loss email to the user after their betslip is settled.
  """

  import Swoosh.Email

  @from_name "WaziBet"
  @from_address "ongeradaryn@gmail.com"

  @doc """
  Builds a win notification email for a settled betslip.

  ## Parameters
    - `user` - The `%WaziBet.Accounts.User{}` struct (must have `:email`)
    - `betslip` - The `%WaziBet.Bets.Betslip{}` struct with `:stake` and `:potential_payout`

  ## Example
      BetslipEmail.won(user, betslip) |> WaziBet.Mailer.deliver()
  """
  def won(user, betslip) do
    payout = format_amount(betslip.potential_payout)
    stake = format_amount(betslip.stake)

    new()
    |> to(user.email)
    |> from({@from_name, @from_address})
    |> subject("🎉 You won #{payout}! Your betslip is a winner")
    |> html_body(won_html(payout, stake))
    |> text_body(won_text(payout, stake))
  end

  @doc """
  Builds a loss notification email for a settled betslip.

  ## Parameters
    - `user` - The `%WaziBet.Accounts.User{}` struct (must have `:email`)
    - `betslip` - The `%WaziBet.Bets.Betslip{}` struct with `:stake`

  ## Example
      BetslipEmail.lost(user, betslip) |> WaziBet.Mailer.deliver()
  """
  def lost(user, betslip) do
    stake = format_amount(betslip.stake)

    new()
    |> to(user.email)
    |> from({@from_name, @from_address})
    |> subject("Your betslip result — better luck next time")
    |> html_body(lost_html(stake))
    |> text_body(lost_text(stake))
  end

  # --- Private Helpers ---

  defp format_amount(%Decimal{} = amount) do
    "KES #{Decimal.round(amount, 2)}"
  end

  defp format_amount(amount) when is_number(amount) do
    "KES #{:erlang.float_to_binary(amount * 1.0, decimals: 2)}"
  end

  defp won_html(payout, stake) do
    """
    <html>
      <body style="font-family: Arial, sans-serif; background: #f4f4f4; padding: 32px;">
        <div style="max-width: 520px; margin: 0 auto; background: #fff; border-radius: 8px; padding: 32px;">
          <h1 style="color: #16a34a;">🎉 Congratulations, you won!</h1>
          <p style="font-size: 16px; color: #374151;">
            Your betslip has been settled and you're a winner.
          </p>
          <table style="width: 100%; border-collapse: collapse; margin: 24px 0;">
            <tr>
              <td style="padding: 8px 0; color: #6b7280;">Stake</td>
              <td style="padding: 8px 0; text-align: right; font-weight: bold;">#{stake}</td>
            </tr>
            <tr>
              <td style="padding: 8px 0; color: #6b7280;">Payout</td>
              <td style="padding: 8px 0; text-align: right; font-weight: bold; color: #16a34a;">#{payout}</td>
            </tr>
          </table>
          <p style="font-size: 14px; color: #6b7280;">
            Your winnings have been credited to your WaziBet account balance.
          </p>
          <p style="font-size: 12px; color: #9ca3af; margin-top: 32px;">
            Please gamble responsibly. If you need support, visit
            <a href="https://www.begambleaware.org">BeGambleAware</a>.
          </p>
        </div>
      </body>
    </html>
    """
  end

  defp won_text(payout, stake) do
    """
    Congratulations, you won!

    Your betslip has been settled and you're a winner.

    Stake:  #{stake}
    Payout: #{payout}

    Your winnings have been credited to your WaziBet account balance.

    Please gamble responsibly.
    """
  end

  defp lost_html(stake) do
    """
    <html>
      <body style="font-family: Arial, sans-serif; background: #f4f4f4; padding: 32px;">
        <div style="max-width: 520px; margin: 0 auto; background: #fff; border-radius: 8px; padding: 32px;">
          <h1 style="color: #dc2626;">Betslip Settled</h1>
          <p style="font-size: 16px; color: #374151;">
            Unfortunately your betslip did not win this time.
          </p>
          <table style="width: 100%; border-collapse: collapse; margin: 24px 0;">
            <tr>
              <td style="padding: 8px 0; color: #6b7280;">Stake lost</td>
              <td style="padding: 8px 0; text-align: right; font-weight: bold; color: #dc2626;">#{stake}</td>
            </tr>
          </table>
          <p style="font-size: 14px; color: #6b7280;">
            Better luck on your next bet. Your account is ready for your next betslip.
          </p>
          <p style="font-size: 12px; color: #9ca3af; margin-top: 32px;">
            Please gamble responsibly. If you need support, visit
            <a href="https://www.begambleaware.org">BeGambleAware</a>.
          </p>
        </div>
      </body>
    </html>
    """
  end

  defp lost_text(stake) do
    """
    Betslip Settled

    Unfortunately your betslip did not win this time.

    Stake lost: #{stake}

    Better luck on your next bet. Your account is ready for your next betslip.

    Please gamble responsibly.
    """
  end
end
