defmodule Elixlog.Repo.Storage do
  @redis_key "visited_links"

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  def start_link(opts) do
    Redix.start_link(host: opts[:hostname], port: opts[:port], database: opts[:database], name: opts[:name])
  end

  def xrange(pid, from, to) do
    command = ["XRANGE", @redis_key, from, to]
    Redix.command(pid, command)
  end

  defp get_next_seq(pid, timestamp) when is_integer(timestamp) do
    command = ["XREVRANGE", @redis_key, timestamp, timestamp, "COUNT", 1]
    {:ok, list} = Redix.command(pid, command)
    case list do
      [first | _ ] ->
        [key | _ ] = first
        case String.split(key, "-") do
          [oldtimestamp, tail] -> 
            if oldtimestamp == "#{timestamp}" do
              {seq, _} = Integer.parse(tail)
              seq = seq + 1
              "#{seq}"
            else
              "1"
            end
          _ ->
            "1"
        end
      _ ->
        "1"
    end
  end

  def xadd(_pid, _timestamp, []) do
    {:ok, nil}
  end

  def xadd(pid, timestamp, values) when is_integer(timestamp) do
    seq = get_next_seq(pid, timestamp)
    command = ["XADD", @redis_key, "#{timestamp}-#{seq}"]
    Redix.command(pid, command ++ values)
  end

  def del(pid) do
    Redix.command(pid, ["DEL", @redis_key])
  end
end
