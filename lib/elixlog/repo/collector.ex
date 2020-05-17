defmodule Elixlog.Repo.Collector do
  alias Elixlog.Repo.Writer
  alias Elixlog.Repo.Error
  alias Elixlog.Repo

  defstruct clock: nil, set: MapSet.new(), timestamp: 0, new_list: []

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

  defp add_to_set(set, new_list) do
    if !Enum.empty?(new_list) do
      Enum.reduce([set | new_list], fn domain, set ->
        MapSet.put(set, domain)
      end)
    else
      set
    end
  end

  defp get_clock(clock) do
    if clock === nil do
      fn -> DateTime.utc_now |> DateTime.to_unix() end
    else
      clock
    end
  end

  defp now(clock, timestamp) do
    now = clock.()
    if now < timestamp do
      raise  Error, message: "Clock should be monotonous"
    end
    now
  end

  def collector(clock, set, timestamp, new_list) when is_integer(timestamp) and is_list(new_list) do
    clock = get_clock(clock)
    now = now(clock, timestamp)

    if now != timestamp do
      if MapSet.size(set) > 0 do
        Writer.write(Repo.redis_key(), set, timestamp)
      end
      collector(clock, MapSet.new(), now, new_list)
    else
      set = add_to_set(set, new_list)
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
          raise  Error, message: "Unknown command #{command}"
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
        raise Error
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
        raise Error
    end
  end
end
