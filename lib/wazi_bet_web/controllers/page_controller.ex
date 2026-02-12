defmodule WaziBetWeb.PageController do
  use WaziBetWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
