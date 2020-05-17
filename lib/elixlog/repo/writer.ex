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

  def writer() do
    receive do
      {:write, command} ->
        IO.inspect command
        {:ok, _ } = Redix.command(:redix, command)
        writer()
      {:sync, caller} ->
        send caller, {:sync}
        writer()
      {:xadd, key, timestamp, values, sender} ->
        command = ["XREVRANGE", key, timestamp, timestamp, "COUNT", 1]
        {:ok, list} = Redix.command(:redix, command)
        seq = case list do
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
        command = ["XADD", key, "#{timestamp}-#{seq}"] ++ values
        {:ok, _ } = Redix.command(:redix, command)
        if sender != nil do
          send sender, {:ok}
        end
        writer()
      command -> 
          raise  __MODULE__, message: "Unknown command #{command}"
    end
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
