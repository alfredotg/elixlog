defmodule Elixlog.Repo.Collector do
  alias Elixlog.Repo.Writer
  use GenServer

  defstruct clock: nil, set: MapSet.new(), timestamp: 0, new_list: [], unsaved: []

  def process_name() do :repo_collector end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, %__MODULE__{}, name: opts[:name])
  end

  defp get_clock(%{clock: nil}) do
    fn -> DateTime.utc_now |> DateTime.to_unix() end
  end

  defp get_clock(state) do
    state.clock
  end

  defp now(state) do    
    clock = get_clock(state)
    now = clock.()
    if now < state.timestamp do
      state.timestamp
    else
      now
    end
  end

  defp add_to_state(state, []) do
    state
  end

  defp add_to_state(state, new_list) when is_list(new_list) do
    set = Enum.reduce([state.set | new_list], fn domain, set ->
      MapSet.put(set, domain)
    end)
    state
      |> Map.put(:set, set)
      |> Map.put(:new_list, [])
  end

  defp work(state) do
    now = now(state)
    state = if now != state.timestamp do
      state = if MapSet.size(state.set) > 0 do
        Writer.write(self(), state.set, state.timestamp)
        Map.put(state, :unsaved, [[state.timestamp, state.set] | state.unsaved])
      else
        state
      end
      state 
        |> Map.put(:timestamp, now) 
        |> Map.put(:set, MapSet.new())
    else
      state
    end
    add_to_state(state, state.new_list)
  end

  @impl true
  def handle_cast({:clean}, state) do
    state = %__MODULE__{clock: state.clock}
    {:noreply, state}
  end

  @impl true
  def handle_cast({:setclock, clock}, state) do
    state = work(Map.put(state, :clock, clock))
    {:noreply, state}
  end

  @impl true
  def handle_cast({:add, new_list}, state) do
    state = Map.put(state, :new_list, new_list)
    state = work(state)
    {:noreply, state}
  end

  @impl true
  def handle_info({:xadd, timestamp}, state) do
    unsaved = state.unsaved |> Enum.filter(fn [t, _] -> t != timestamp end)
    state = Map.put(state, :unsaved, unsaved)
    {:noreply, state}
  end

  @impl true
  def handle_call({:sync}, _from,  state) do
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:get, from, to}, _from, state) when is_integer(from) and is_integer(to) do
    unsaved = [[state.timestamp, state.set] | state.unsaved]
    uniq = Enum.reduce([MapSet.new() | unsaved], fn([t, set], uniq) -> 
      if t >= from and t <= to do
        MapSet.union(uniq, set)
      else
        uniq
      end
    end)
    {:reply, uniq, state}
  end

  def clean(pid) do
    GenServer.cast(pid, {:clean})
  end

  def clean!(pid) do
    clean(pid)
    sync(pid)
  end

  def clean!() do
    clean!(process_name())
  end

  def sync(pid) do
    GenServer.call(pid, {:sync})
  end

  def get(pid, from, to) when is_integer(from) and is_integer(to) do
    GenServer.call(pid, {:get, from, to})
  end

  def set_clock(pid, clock) do
    GenServer.cast(pid, {:setclock, clock})
  end

  def add(pid, list) when is_pid(pid) and is_list(list) do
    GenServer.cast(pid, {:add, list})
  end

  def add!(pid, list) when is_pid(pid) and is_list(list) do
    add(pid, list)
    sync(pid)
  end
end
