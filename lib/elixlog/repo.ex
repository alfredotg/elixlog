defmodule Elixlog.Repo do
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

  def save_links(links) when is_list(links) do
    links = Enum.map(links, fn uri -> 
      if uri.host != nil do
        uri.host
      else
        uri.path
      end
    end)
    links = Enum.filter(links, &(is_binary(&1))) 
            |> Enum.flat_map(&([&1, "1"]))
    command = ["XADD", @redis_key, "*"] ++ links
    Redix.command(:redix, command)
  end

  def get_domains(from, to) when is_integer(from) and is_integer(to) do
    to_msec = &(&1*1000)
    command = ["XRANGE", @redis_key, to_msec.(from), to_msec.(to) + 999]
    case Redix.command(:redix, command) do
      {:ok, list} ->
        mset = Enum.reduce([MapSet.new() | list], fn row, mset -> 
          [_, domains] = row
          Enum.reduce([mset | Enum.chunk_every(domains, 2)], fn row, mset ->
            [domain, _] = row
            MapSet.put(mset, domain)
          end)
        end)
        {:ok, MapSet.to_list(mset)}
      {:error, error} ->
        {:error, error}
    end
  end
end
