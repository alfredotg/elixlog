defmodule Elixlog.Repo.Writer do
  defexception message: "timeout"

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  def process_name() do :repo_writer end

  def start_link([]) do
    {ok, pid} = Task.start_link(fn -> writer() end)
    Process.register(pid, process_name())
    {ok, pid}
  end

  defp get_next_seq(key, timestamp) do
    command = ["XREVRANGE", key, timestamp, timestamp, "COUNT", 1]
    {:ok, list} = Redix.command(:redix, command)
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

  def writer() do
    receive do
      {:pause} ->
        receive do
          {:resume} ->
            writer()
        end
      {:sync, caller} ->
        send caller, {:sync}

        writer()

      {:xadd, key, timestamp, values, sender} ->
        seq = get_next_seq(key, timestamp)
        command = ["XADD", key, "#{timestamp}-#{seq}"]
        {:ok, _ } = Redix.command(:redix, command ++ values)
        if sender != nil do
          send sender, {:xadd, timestamp}
        end

        writer()

      command -> 
          raise  __MODULE__, message: "Unknown command #{command}"
    end
  end

  def write(sender, key, set, timestamp) when is_pid(sender) and is_binary(key) and is_integer(timestamp) do
    command = Enum.filter(MapSet.to_list(set), &is_binary/1) 
            |> Enum.flat_map(&([&1, "1"]))
    send process_name(), {:xadd, key, timestamp, command, sender}
  end


  def sync() do
    send process_name(), {:sync, self()}
    receive do
      {:sync} ->
        {:ok}
    after
      1000 ->
        raise __MODULE__
    end
  end
end
