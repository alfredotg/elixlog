defmodule Elixlog.RepoCollectorTest do
  use ElixlogWeb.ConnCase
  alias Elixlog.Repo.Collector
  alias Elixlog.Repo.Collector
  alias Elixlog.Repo.Writer
  alias Elixlog.Repo.Storage
  alias Elixlog.Repo

  test "Collector.get", %{conn: _} do
    clean_db()
  
    {:ok, pid} = Collector.start_link([name: nil, writer: Writer])

    mset = Collector.get(pid, 0, 0)
    assert assert [] = MapSet.to_list(mset)

    GenServer.stop(pid)
  end

  test "Collector.add", %{conn: _} do
    clean_db()

    {:ok, pid} = Collector.start_link([name: nil, writer: Writer])

    set_clock_and_clean(pid, fn -> 1000 end)

    Collector.add!(pid, ["ya.ru", "google.com"])
    Collector.add!(pid, ["ms.com"])
    ## collector collects domains
    mset = Collector.get(pid, 1000, 1000)
    list = Enum.sort(MapSet.to_list(mset))
    assert assert ["google.com", "ms.com", "ya.ru"] = list

    ## storage is empty 
    {:ok, list} = Storage.xrange(1000, 1000)
    assert assert [] = list 

    ## ticking..., save
    set_clock(pid, fn -> 1001 end)
    Writer.sync(Writer)

    ## unsaved is empty
    mset = Collector.get(pid, 1000, 1000)
    list = Enum.sort(MapSet.to_list(mset))
    assert assert [] = list

    {:ok, list} = Repo.get_domains(1000, 1000)
    list = Enum.sort(list)
    assert assert ["google.com", "ms.com", "ya.ru"] = list

    GenServer.stop(pid)
  end

  test "Collector.cache", %{conn: _} do
    clean_db()

    {:ok, pid} = Collector.start_link([name: nil, writer: Writer])

    set_clock_and_clean(pid, fn -> 1000 end)
    Writer.pause(Writer)

    Collector.add!(pid, ["ms.com"])
    set_clock(pid, fn -> 1001 end)
    Collector.add!(pid, ["ya.com"])
    set_clock(pid, fn -> 1002 end)

    mset = Collector.get(pid, 1000, 1000)
    assert assert ["ms.com"] = MapSet.to_list(mset)

    mset = Collector.get(pid, 1000, 1001)
    assert assert ["ms.com", "ya.com"] = Enum.sort(MapSet.to_list(mset))

    send Writer, {:resume}
    Writer.sync(Writer)

    # clean cache after save
    mset = Collector.get(pid, 1000, 1001)
    assert assert [] = MapSet.to_list(mset)

    # restore clock
    GenServer.stop(pid)
  end

  defp set_clock(pid, clock) do
    Collector.set_clock(pid, clock)
    Collector.sync(pid)
  end

  defp set_clock_and_clean(pid, clock) do
    Collector.clean!(pid)
    Collector.set_clock(pid, clock)
    clean_db()
  end
end
