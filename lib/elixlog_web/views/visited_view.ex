defmodule ElixlogWeb.VisitedView do
  use ElixlogWeb, :view
  
  def render("visited_links.json", %{status: status}) do
    %{status: status}
  end
end

