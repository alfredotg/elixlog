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
      collector(%__MODULE__{}) 
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

  defp get_clock(collector) do
    if collector.clock === nil do
      fn -> DateTime.utc_now |> DateTime.to_unix() end
    else
      collector.clock
    end
  end

  defp now(collector) do
    now = collector.clock.()
    if now < collector.timestamp do
      raise  Error, message: "Clock should be monotonous"
    end
    now
  end

  def collector(data) do
    data = %{data | clock: get_clock(data)}
    now = now(data)

    if now != data.timestamp do
      if MapSet.size(data.set) > 0 do
        Writer.write(Repo.redis_key(), data.set, data.timestamp)
      end
      data = %{data | timestamp: now, set: MapSet.new()}
      collector(data)
    else
      data = %{data | set: add_to_set(data.set, data.new_list), new_list: []}
      receive do
        {:reset, clock} ->
          data = %__MODULE__{clock: clock}
          collector(data)

        {:setclock, clock} ->
          data = %{data | clock: clock}
          collector(data)

        {:sync, caller} ->
          send caller, {:sync}
          collector(data)

        {:clean} ->
          data = %__MODULE__{clock: data.clock}
          collector(data)

        {:add, new_list} ->
          data = %{data | new_list: new_list}
          collector(data)

        {:get, caller} ->
          send caller, {:domains, MapSet.to_list(data.set), data.timestamp}
          collector(data)

        command -> 
          raise  Error, message: "Unknown command #{command}"
      after
        100 -> 
          collector(data)
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
