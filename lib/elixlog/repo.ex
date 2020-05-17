defmodule Elixlog.Repo do
  alias Elixlog.Repo.Collector

  @redis_key "visited_links"

  def redis_key do @redis_key end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  def start_link([]) do
    conf = Application.get_env(:elixlog, __MODULE__)
    {:ok, _} = Redix.start_link(host: conf[:hostname], port: conf[:port], database: conf[:database], name: :redix)
  end

  def save_domains(domains) when is_list(domains) do
    Collector.add(domains)
    {:ok, domains}
  end

  def get_domains(from, to) when is_integer(from) and is_integer(to) do
    command = ["XRANGE", @redis_key, from, to]
    case Redix.command(:redix, command) do
      {:ok, list} ->
        mset = Enum.reduce([MapSet.new() | list], fn row, mset -> 
          [_, domains] = row
          Enum.reduce([mset | Enum.chunk_every(domains, 2)], fn row, mset ->
            [domain, _] = row
            MapSet.put(mset, domain)
          end)
        end)
        {unsaved, time} = Collector.get()
        mset = if time >= from && time <= to do
          Enum.reduce([mset | unsaved], fn domain, mset -> 
            MapSet.put(mset, domain)
          end)
        else
          mset
        end
        {:ok, MapSet.to_list(mset)}
      {:error, error} ->
        {:error, error}
    end
  end
end
