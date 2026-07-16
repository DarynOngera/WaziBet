defmodule WaziBetWeb.GameLive.Components do
  @moduledoc """
  Shared components for Game LiveViews.
  """

  use Phoenix.Component
  use WaziBetWeb, :verified_routes

  import WaziBetWeb.CoreComponents, only: [icon: 1]

  # alias Phoenix.LiveView.JS

  attr :betslip, :list, required: true
  attr :open, :boolean, default: false
  attr :current_scope, :map, default: nil
  attr :stake, :string, default: "100"

  def sidebar_betslip(assigns) do
    total_odds = calculate_total_odds(assigns.betslip)

    assigns =
      assigns
      |> assign(:total_odds, total_odds)

    ~H"""
    <%!-- Desktop Sidebar --%>
    <div class={[
      "hidden lg:block fixed right-0 top-16 bottom-0 w-80 bg-base-100 shadow-2xl transform transition-transform duration-300 z-40 border-l-2 border-base-300",
      if(@open, do: "translate-x-0", else: "translate-x-full")
    ]}>
      <div class="flex flex-col h-full">
        <%!-- Header --%>
        <div class="p-4 border-b-2 border-base-200 flex justify-between items-center bg-base-200">
          <h2 class="type-h2 flex items-center gap-2">
            <.icon name="hero-ticket" class="w-5 h-5 text-primary" /> Betslip
          </h2>
          <button phx-click="close_sidebar" class="btn btn-ghost btn-sm btn-circle">
            <.icon name="hero-x-mark" class="w-5 h-5" />
          </button>
        </div>

        <%!-- Content --%>
        <div class="flex-1 overflow-y-auto p-4">
          <%= if Enum.empty?(@betslip) do %>
            <div class="text-center text-base-content/50 py-12">
              <div class="w-16 h-16 mx-auto mb-4 rounded-full bg-base-200 flex items-center justify-center">
                <.icon name="hero-ticket" class="w-8 h-8 opacity-50" />
              </div>
              <p class="font-medium">Your betslip is empty</p>
              <p class="text-sm mt-2">Click on odds to add selections</p>
            </div>
          <% else %>
            <div class="space-y-3">
              <%= for {selection, index} <- Enum.with_index(@betslip) do %>
                <div class="card bg-base-200 border border-base-300">
                  <div class="card-body p-4">
                    <div class="flex justify-between items-start">
                      <div class="flex-1 min-w-0">
                        <p class="font-medium truncate">{get_field(selection, :game_name)}</p>
                        <p class="text-sm text-base-content/60 mt-1 font-mono">
                          {String.capitalize(to_string(get_field(selection, :label)))} @ {format_odds(
                            get_field(selection, :odds)
                          )}
                        </p>
                      </div>
                      <button
                        phx-click="remove_from_betslip"
                        phx-value-index={index}
                        class="btn btn-ghost btn-sm btn-circle ml-3 text-error hover:bg-error/10"
                      >
                        <.icon name="hero-x-mark" class="w-5 h-5" />
                      </button>
                    </div>
                  </div>
                </div>
              <% end %>

              <button phx-click="clear_betslip" class="btn btn-ghost btn-sm w-full">
                <.icon name="hero-trash" class="w-4 h-4 mr-2" /> Clear All
              </button>
            </div>
          <% end %>
        </div>

        <%!-- Footer with totals and action --%>
        <%= if not Enum.empty?(@betslip) do %>
          <% stake_value = @stake || "100" %>
          <form
            phx-submit="place_bet"
            phx-change="update_stake"
            class="border-t-2 border-base-200 p-4 space-y-4 bg-base-200"
          >
            <div class="flex justify-between items-center text-sm">
              <span class="text-base-content/60">Total Odds:</span>
              <span class="font-bold text-lg font-mono text-primary">{@total_odds}</span>
            </div>

            <div class="form-control">
              <label class="label">
                <span class="label-text font-medium">Stake Amount</span>
                <span class="label-text-alt font-mono">Min: $10</span>
              </label>
              <div class="join">
                <span class="btn btn-square btn-outline no-animation join-item border-2">$</span>
                <input
                  type="number"
                  name="stake"
                  value={stake_value}
                  min="10"
                  class="input input-bordered w-full join-item border-2"
                />
              </div>
            </div>

            <div class="flex justify-between items-center text-sm">
              <span class="text-base-content/60">Potential Win:</span>
              <span class="font-bold text-success text-lg font-mono">
                ${calculate_potential_win(@total_odds, stake_value)}
              </span>
            </div>

            <%= if @current_scope && @current_scope.user do %>
              <button type="submit" class="btn btn-primary w-full border-2">
                <.icon name="hero-check" class="w-5 h-5 mr-2" /> Place Bet ({stake_value})
              </button>
            <% else %>
              <div class="space-y-2">
                <div class="alert alert-warning text-sm py-2 border-2 border-warning">
                  <.icon name="hero-exclamation-triangle" class="w-4 h-4 shrink-0" />
                  <span>Login to place your bet</span>
                </div>
                <.link
                  navigate={"/users/log-in?return_to=" <> URI.encode_www_form("/games")}
                  class="btn btn-primary w-full border-2"
                >
                  <.icon name="hero-arrow-right-on-rectangle" class="w-4 h-4 mr-2" /> Login to Bet
                </.link>
              </div>
            <% end %>
          </form>
        <% end %>
      </div>
    </div>

    <%!-- Mobile Full Screen Modal --%>
    <div class={["lg:hidden fixed inset-0 z-50", if(@open, do: "block", else: "hidden")]}>
      <%!-- Backdrop --%>
      <div class="absolute inset-0 bg-black/60 backdrop-blur-sm" phx-click="close_sidebar"></div>

      <%!-- Modal --%>
      <div class="absolute inset-x-0 bottom-0 top-20 bg-base-100 rounded-t-2xl shadow-2xl flex flex-col border-t-2 border-base-300">
        <%!-- Handle bar --%>
        <div class="flex justify-center pt-3 pb-1" phx-click="close_sidebar">
          <div class="w-12 h-1 bg-base-300 rounded-full"></div>
        </div>

        <%!-- Header --%>
        <div class="px-4 py-3 border-b-2 border-base-200 flex justify-between items-center bg-base-200">
          <h2 class="type-h2 flex items-center gap-2">
            <.icon name="hero-ticket" class="w-5 h-5 text-primary" /> Betslip
          </h2>
          <button phx-click="close_sidebar" class="btn btn-ghost btn-sm btn-circle">
            <.icon name="hero-x-mark" class="w-5 h-5" />
          </button>
        </div>

        <%!-- Content --%>
        <div class="flex-1 overflow-y-auto p-4">
          <%= if Enum.empty?(@betslip) do %>
            <div class="text-center text-base-content/50 py-12">
              <div class="w-16 h-16 mx-auto mb-4 rounded-full bg-base-200 flex items-center justify-center">
                <.icon name="hero-ticket" class="w-8 h-8 opacity-50" />
              </div>
              <p class="text-lg font-medium">Your betslip is empty</p>
              <p class="text-sm mt-2">Click on odds to add selections</p>
            </div>
          <% else %>
            <div class="space-y-3">
              <%= for {selection, index} <- Enum.with_index(@betslip) do %>
                <div class="card bg-base-200 border border-base-300">
                  <div class="card-body p-4">
                    <div class="flex justify-between items-start">
                      <div class="flex-1 min-w-0">
                        <p class="font-medium truncate">{get_field(selection, :game_name)}</p>
                        <p class="text-sm text-base-content/60 mt-1 font-mono">
                          {String.capitalize(to_string(get_field(selection, :label)))} @ {format_odds(
                            get_field(selection, :odds)
                          )}
                        </p>
                      </div>
                      <button
                        phx-click="remove_from_betslip"
                        phx-value-index={index}
                        class="btn btn-ghost btn-sm btn-circle ml-3 text-error hover:bg-error/10"
                      >
                        <.icon name="hero-x-mark" class="w-5 h-5" />
                      </button>
                    </div>
                  </div>
                </div>
              <% end %>

              <button phx-click="clear_betslip" class="btn btn-ghost btn-sm w-full mt-4">
                <.icon name="hero-trash" class="w-4 h-4 mr-2" /> Clear All
              </button>
            </div>
          <% end %>
        </div>

        <%!-- Footer --%>
        <%= if not Enum.empty?(@betslip) do %>
          <% stake_value = @stake || "100" %>
          <form phx-submit="place_bet" class="border-t-2 border-base-200 p-4 space-y-4 bg-base-200">
            <div class="flex justify-between items-center">
              <span class="text-base-content/60">Total Odds:</span>
              <span class="font-bold text-xl font-mono text-primary">{@total_odds}</span>
            </div>

            <div class="form-control">
              <label class="label">
                <span class="label-text font-medium">Stake Amount</span>
              </label>
              <div class="join">
                <span class="btn btn-square btn-outline no-animation join-item border-2">$</span>
                <input
                  type="number"
                  name="stake"
                  value={stake_value}
                  min="10"
                  class="input input-bordered w-full join-item border-2"
                />
              </div>
            </div>

            <div class="flex justify-between items-center">
              <span class="text-base-content/60">Potential Win:</span>
              <span class="font-bold text-success text-lg font-mono">
                ${calculate_potential_win(@total_odds, stake_value)}
              </span>
            </div>

            <%= if @current_scope && @current_scope.user do %>
              <button type="submit" class="btn btn-primary btn-lg w-full border-2">
                <.icon name="hero-check" class="w-5 h-5 mr-2" /> Place Bet ({stake_value})
              </button>
            <% else %>
              <div class="space-y-3">
                <div class="alert alert-warning border-2 border-warning">
                  <.icon name="hero-exclamation-triangle" class="w-6 h-6 shrink-0" />
                  <span>Login required to place bets</span>
                </div>
                <.link
                  navigate={"/users/log-in?return_to=" <> URI.encode_www_form("/games")}
                  class="btn btn-primary btn-lg w-full border-2"
                >
                  <.icon name="hero-arrow-right-on-rectangle" class="w-5 h-5 mr-2" /> Login to Bet
                </.link>
              </div>
            <% end %>
          </form>
        <% end %>
      </div>
    </div>
    """
  end

  def is_selected?(betslip, outcome_id) do
    Enum.any?(betslip, fn selection ->
      (Map.get(selection, "outcome_id") || Map.get(selection, :outcome_id)) == outcome_id
    end)
  end

  defp get_field(map, key, default \\ nil) do
    Map.get(map, key) || Map.get(map, to_string(key)) || default
  end

  defp format_odds(odds) do
    case odds do
      %{"coef" => coef, "exp" => exp, "sign" => sign} ->
        result = coef * :math.pow(10, exp) * sign
        format_decimal(result)

      %Decimal{} = d ->
        Decimal.to_string(d, :normal)

      odds when is_binary(odds) ->
        odds

      odds when is_number(odds) ->
        format_decimal(odds)

      _ ->
        "N/A"
    end
  end

  defp format_decimal(num) when is_float(num) do
    :erlang.float_to_binary(num, [{:decimals, 2}, :compact])
  end

  defp format_decimal(num) when is_integer(num) do
    Integer.to_string(num)
  end

  defp calculate_total_odds([]), do: Decimal.new(1)

  defp calculate_total_odds(betslip) do
    betslip
    |> Enum.map(fn selection ->
      case Map.get(selection, "odds") || Map.get(selection, :odds) do
        nil ->
          Decimal.new(1)

        odds when is_map(odds) ->
          if Map.has_key?(odds, "coef") do
            coef = Map.get(odds, "coef", 0)
            exp = Map.get(odds, "exp", 0)
            sign = Map.get(odds, "sign", 1)
            result = coef * :math.pow(10, exp) * sign
            Decimal.new(Float.to_string(result))
          else
            case Decimal.cast(odds) do
              {:ok, decimal} -> decimal
              _ -> Decimal.new(1)
            end
          end

        odds when is_binary(odds) ->
          Decimal.new(odds)

        odds ->
          case Decimal.cast(odds) do
            {:ok, decimal} -> decimal
            _ -> Decimal.new(1)
          end
      end
    end)
    |> Enum.reduce(Decimal.new(1), &Decimal.mult/2)
    |> Decimal.round(2)
  end

  defp calculate_potential_win(total_odds, stake) do
    stake_decimal = Decimal.new(stake)

    total_odds
    |> Decimal.mult(stake_decimal)
    |> Decimal.round(2)
    |> Decimal.to_string(:normal)
  end
end
