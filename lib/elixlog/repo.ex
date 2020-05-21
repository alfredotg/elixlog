defmodule Elixlog.Repo do
  alias Elixlog.Repo.Collector
  alias Elixlog.Repo.Storage

  def collector_process() do Collector end
  def storage_process() do Storage end

  def save_domains(domains) when is_list(domains) do
    Collector.add(collector_process(), domains)
    {:ok, domains}
  end

  def get_domains(from, to) when is_integer(from) and is_integer(to) do
    mset = Collector.get(collector_process(), from, to)
    case Storage.xrange(storage_process(), from, to) do
      {:ok, list} ->
        list = [mset | list]
        mset = list |> Enum.reduce(fn [_, domains], mset -> 
          list = [mset | Enum.chunk_every(domains, 2)]
          list |> Enum.reduce(fn [domain, _], mset ->
            MapSet.put(mset, domain)
          end)
        end)
        {:ok, MapSet.to_list(mset)}
      {:error, error} ->
        {:error, error}
    end
  end
end
