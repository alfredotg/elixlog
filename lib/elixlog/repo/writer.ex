defmodule Elixlog.Repo.Writer do
  alias Elixlog.Repo.Storage
  use GenServer

  def process_name() do :repo_writer end

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
    GenServer.start_link(__MODULE__, %{}, name: opts[:name])
  end

  @impl true
  def handle_cast({:pause}, state) do
    receive do
      {:resume} ->
        state
    end
    {:noreply, state}
  end

  @impl true
  def handle_cast({:xadd, timestamp, values, sender}, state) do
    {:ok, _ } = Storage.xadd(timestamp, values)
    if sender != nil do
      send sender, {:xadd, timestamp}
    end
    {:noreply, state}
  end

  @impl true
  def handle_call({:sync}, _from,  state) do
    {:reply, :ok, state}
  end


  def write(sender, set, timestamp) when is_map(set) and (is_pid(sender) or is_nil(sender)) and is_integer(timestamp) do
    values = Enum.filter(MapSet.to_list(set), &is_binary/1) 
            |> Enum.flat_map(&([&1, "1"]))

    GenServer.cast(process_name(), {:xadd, timestamp, values, sender})
  end


  def sync() do
    GenServer.call(process_name(), {:sync})
  end

  def pause() do
    GenServer.cast(process_name(), {:pause})
  end

  def resume() do
    send process_name(), {:resume}
  end
end
