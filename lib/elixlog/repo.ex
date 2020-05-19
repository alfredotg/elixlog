defmodule Elixlog.Repo do
  alias Elixlog.Repo.Collector
  alias Elixlog.Repo.Storage

  def collector_process() do Collector end

  def save_domains(domains) when is_list(domains) do
    Collector.add(collector_process(), domains)
    {:ok, domains}
  end

  def get_domains(from, to) when is_integer(from) and is_integer(to) do
    case Storage.xrange(from, to) do
      {:ok, list} ->
        list = [MapSet.new() | list]
        mset = list |> Enum.reduce(fn [_, domains], mset -> 
          list = [mset | Enum.chunk_every(domains, 2)]
          list |> Enum.reduce(fn [domain, _], mset ->
            MapSet.put(mset, domain)
          end)
        end)
        mset = MapSet.union(mset, Collector.get(collector_process(), from, to))
        {:ok, MapSet.to_list(mset)}
      {:error, error} ->
        {:error, error}
    end
  end
end
