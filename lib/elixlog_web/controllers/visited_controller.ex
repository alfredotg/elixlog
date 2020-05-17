defmodule ElixlogWeb.VisitedController do
  use ElixlogWeb, :controller
  alias Elixlog.Repo

  def post(conn, params) do
    case params do
      %{"links" => links} when is_list(links) ->
        links = links |> Enum.filter(&(is_binary(&1))) |> Enum.map(&(URI.parse(&1)))  
        case Repo.save_links(links) do
          {:ok, _} ->
            json(conn, %{status: :ok})
          {:error, error} ->
            json(conn, redis_error(error))
        end

      _ ->
        bad_request(conn, params)
    end
  end

  def get(conn, params) do
    case params do
      %{"from" => from, "to" => to} when is_binary(from) and is_binary(to) ->
        case parse_ints([from, to]) do
          :error ->
            bad_request(conn, params)
          [from, to] ->
            case Repo.get_domains(from, to) do
              {:ok, domains} ->
                json(conn, %{domains: domains, status: :ok})
              {:error, error} ->
                json(conn, redis_error(error))
            end
        end
      _ ->
        bad_request(conn, params)
    end
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
