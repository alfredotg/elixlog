defmodule ElixlogWeb.PageController do
  use ElixlogWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
