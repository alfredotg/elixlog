defmodule Elixlog.Repo.Collector do
  alias Elixlog.Repo.Writer
  alias Elixlog.Repo.Error

  defstruct clock: nil, set: MapSet.new(), timestamp: 0, new_list: [], unsaved: []

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

  defp add_to_set(set, []) do
    set
  end

  defp add_to_set(set, new_list) do
    Enum.reduce([set | new_list], fn domain, set ->
      MapSet.put(set, domain)
    end)
  end

  defp get_clock(state) do
    if state.clock === nil do
      fn -> DateTime.utc_now |> DateTime.to_unix() end
    else
      state.clock
    end
  end

  defp now(state) do    
    clock = get_clock(state)
    now = clock.()
    if now < state.timestamp do
      raise  Error, message: "Clock should be monotonous"
    else
      now
    end
  end

  def collector(state) do
    now = now(state)

    if now != state.timestamp do
      state = if MapSet.size(state.set) > 0 do
        Writer.write(self(), state.set, state.timestamp)
        %{state | unsaved: [[state.timestamp, state.set] | state.unsaved]}
      else
        state
      end
      state = %{state | timestamp: now, set: MapSet.new()}
      collector(state)
    else
      state = %{state | set: add_to_set(state.set, state.new_list), new_list: []}
      receive do
        {:reset, clock} ->
          state = %__MODULE__{clock: clock}
          collector(state)

        {:setclock, clock} ->
          state = %{state | clock: clock}
          collector(state)

        {:xadd, timestamp} ->
          unsaved = state.unsaved |> Enum.filter(fn [t, _] -> t != timestamp end)
          state = %{state | unsaved: unsaved}
          collector(state)

        {:sync, caller} ->
          send caller, {:sync}
          collector(state)

        {:clean} ->
          state = %__MODULE__{clock: state.clock}
          collector(state)

        {:add, new_list} ->
          state = %{state | new_list: new_list}
          collector(state)

        {:get, caller, from, to} ->
          unsaved = [[state.timestamp, state.set] | state.unsaved]
          uniq = Enum.reduce([MapSet.new() | unsaved], fn([t, set], uniq) -> 
            if t >= from and t <= to do
              MapSet.union(uniq, set)
            else
              uniq
            end
          end)
          send caller, {:domains, uniq}
          collector(state)

        command -> 
          raise  Error, message: "Unknown command #{command}"
      after
        100 -> 
          collector(state)
      end
    end
  end

  def get(from, to) when is_integer(from) and is_integer(to) do
    send process_name(), {:get, self(), from, to}
    receive do
      {:domains, mset} ->
        mset
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
