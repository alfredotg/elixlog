defmodule Elixlog.Repo.Collector do
  alias Elixlog.Repo
  alias Elixlog.Repo.Writer

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

  def process_name() do :repo_collector end

  def start_link([]) do
    {ok, pid} = Task.start_link(fn -> 
      collector(nil, MapSet.new(), 0, []) 
    end)
    Process.register(pid, process_name())
    {ok, pid}
  end

  def collector(clock, set, timestamp, new_list) do
    clock = if clock === nil do
      fn -> DateTime.utc_now |> DateTime.to_unix() end
    else
      clock
    end
    now = clock.()
    now = if now < timestamp do
      raise  __MODULE__, message: "Clock should be monotonous"
    else
      now
    end
    if now != timestamp do
      if MapSet.size(set) > 0 do
        command = Enum.filter(MapSet.to_list(set), &is_binary/1) 
                |> Enum.flat_map(&([&1, "1"]))
        send Writer.process_name(), {:xadd, Repo.redis_key(), timestamp, command, nil}
      end
      collector(clock, MapSet.new(), now, new_list)
    else
      set = if !Enum.empty?(new_list) do
        Enum.reduce([set | new_list], fn domain, set ->
          MapSet.put(set, domain)
        end)
      else
        set
      end
      receive do
        {:reset, clock} ->
          collector(clock, MapSet.new(), 0, [])
        {:setclock, clock} ->
          collector(clock, set, now, [])
        {:sync, caller} ->
          send caller, {:sync}
          collector(clock, set, now, [])
        {:clean} ->
          collector(clock, MapSet.new(), 0, [])
        {:add, new_list} ->
          collector(clock, set, now, new_list)
        {:get, caller} ->
          send caller, {:domains, MapSet.to_list(set), now}
          collector(clock, set, now, [])
        command -> 
          raise  __MODULE__, message: "Unknown command #{command}"
      after
        100 -> 
          collector(clock, set, now, [])
      end
    end
  end

  def get() do
    send process_name(), {:get, self()}
    receive do
      {:domains, list, time} ->
        {list, time}
    after
      1000 ->
        raise __MODULE__
    end
  end

  def add(list) when is_list(list) do
    send process_name(), {:add, list}
  end

  def add!(list) when is_list(list) do
    add(list)
    sync()
  end

  def clean() do
    send process_name(), {:clean}
  end

  def clean!() do
    clean()
    sync()
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
