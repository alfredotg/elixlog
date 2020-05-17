defmodule ElixlogWeb.PageController do
  use ElixlogWeb, :controller

  def index(conn, _params) do
    text(conn, "phoenix api server")
  end
end
