defmodule ElixlogWeb.VisitedControllerTest do
  use ElixlogWeb.ConnCase
  alias Elixlog.Repo.Collector

  test "POST /visited_links 200", %{conn: conn} do
    clean_db()

    conn = post(conn, "/visited_links", %{links: ["https://ya.ru", "funbox.ru"]})
    assert assert %{"status" => "ok"} = json_response(conn, 200) 
  end

  test "POST /visited_links bad request", %{conn: conn} do
    conn = post(conn, "/visited_links", %{list: ["https://ya.ru", "funbox.ru"]})
    assert assert %{"status" => "Error: bad request"} = json_response(conn, 200) 
  end

  test "GET /visited_links 200", %{conn: conn} do
    clean_db()

    conn = post(conn, "/visited_links", %{links: [
      "https://ya.ru?q=123", 
      "https://ya.ru", 
      "https://stackoverflow.com/questions/11828270/how-to-exit-the-vim-editor",
      "funbox.ru"]})
    assert assert %{"status" => "ok"} = json_response(conn, 200) 

    Collector.sync(Collector.process_name())

    time = DateTime.utc_now() |> DateTime.to_unix()
    conn = get(conn, "/visited_domains", %{from: time - 10, to: time})
    response = json_response(conn, 200)
    assert assert %{"status" => "ok"} = response  

    domains = Enum.sort(response["domains"])
    assert assert ["funbox.ru", "stackoverflow.com", "ya.ru"] = domains  
  end

  test "GET /visited_links with range", %{conn: conn} do
    clean_db()

    conn = post(conn, "/visited_links", %{links: ["https://ya.ru", "funbox.ru"]})
    assert assert %{"status" => "ok"} = json_response(conn, 200) 

    Collector.sync(Collector.process_name())

    conn = get(conn, "/visited_domains", %{from: 0, to: 1})
    response = json_response(conn, 200)
    assert assert %{"status" => "ok"} = response  
    assert assert [] = response["domains"]  
  end

  test "GET /visited_links bad params", %{conn: conn} do
    conn = get(conn, "/visited_domains", %{from: "hello", to: 1})
    assert assert %{"status" => "Error: bad request"} = json_response(conn, 200) 
  end
end
