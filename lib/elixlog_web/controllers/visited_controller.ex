defmodule ElixlogWeb.VisitedController do
  use ElixlogWeb, :controller

  def post(conn, _params) do
    text(conn, "saved")
  end

  def get(conn, _params) do
    text(conn, "get")
  end
end
