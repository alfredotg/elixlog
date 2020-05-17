defmodule ElixlogWeb.VisitedController do
  use ElixlogWeb, :controller
  alias Elixlog.Repo

  def post(conn, %{"links" => links}) when is_list(links) do
    links = links |> Enum.filter(&is_binary/1) |> Enum.map(&URI.parse/1)  
    links = Enum.map(links, fn uri -> 
      if uri.host != nil do
        uri.host
      else
        uri.path
      end
    end)
    links = Enum.filter(links, &is_binary/1) |> Enum.uniq()
    case Repo.save_domains(links) do
      {:ok, _} ->
        json(conn, %{status: :ok})
      {:error, error} ->
        json(conn, redis_error(error))
    end
  end

  def post(conn, params) do
    bad_request(conn, params)
  end

  defp get(conn, from, to) when is_integer(from) and is_integer(to) do
    case Repo.get_domains(from, to) do
      {:ok, domains} ->
        json(conn, %{domains: domains, status: :ok})
      {:error, error} ->
        json(conn, redis_error(error))
    end
  end

  def get(conn, %{"from" => from, "to" => to}) when is_binary(from) and is_binary(to) do
    case parse_ints([from, to]) do
      :error ->
        bad_request(conn, %{from: from, to: to})
      [from, to] ->
        get(conn, from, to)
    end
  end

  def get(conn, params) do
    bad_request(conn, params)
  end

  defp bad_request(conn, params) do
      json(conn, %{status: "Error: bad request", params: params})
  end

  defp redis_error(error) do
    IO.inspect error
    %{status: "Error: server error"}
  end

  defp parse_ints([]) do
    []
  end

  defp parse_ints(list) when is_list(list) do
    [head | tail] = list
    case Integer.parse(head) do
      :error ->
        :error
      {int, _} ->
        case parse_ints(tail) do
          :error -> 
            :error
          list ->
            [int | list]
        end
    end
  end
end
