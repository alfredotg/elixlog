defmodule Elixlog.RepoTest do
  use ElixlogWeb.ConnCase
  alias Elixlog.Repo.Collector
  alias Elixlog.Repo.Writer
  alias Elixlog.Repo

  test "Collector.get", %{conn: _} do
    clean_db()

    Collector.clean!()
    mset = Collector.get(0, 0)
    assert assert [] = MapSet.to_list(mset)
  end

  test "Collector.add", %{conn: _} do
    clean_db()
    Collector.clean!()

    set_clock_and_clean(fn -> 1000 end)

    Collector.add!(["ya.ru", "google.com"])
    Collector.add!(["ms.com"])
    # collector collects domains
    mset = Collector.get(1000, 1000)
    list = Enum.sort(MapSet.to_list(mset))
    assert assert ["google.com", "ms.com", "ya.ru"] = list

    # storage is empty 
    {:ok, list} = Redix.command(:redix, ["XRANGE", Repo.redis_key(), 1000, 1000])
    assert assert [] = list 

    # repo gets data from collector
    {:ok, list} = Repo.get_domains(1000, 1000)
    list = Enum.sort(list)
    assert assert ["google.com", "ms.com", "ya.ru"] = list

    # if time matchs
    {:ok, list} = Repo.get_domains(1001, 1001)
    list = Enum.sort(list)
    assert assert [] = list

    # ticking..., save
    set_clock(fn -> 1001 end)
    Writer.sync()

    # unsaved is empty
    mset = Collector.get(1000, 1000)
    list = Enum.sort(MapSet.to_list(mset))
    assert assert [] = list

    {:ok, list} = Repo.get_domains(1000, 1000)
    list = Enum.sort(list)
    assert assert ["google.com", "ms.com", "ya.ru"] = list

    # restore clock
    set_clock_and_clean(nil)
  end

  test "Collector.cache", %{conn: _} do
    clean_db()
    Collector.clean!()

    set_clock_and_clean(fn -> 1000 end)
    send Writer.process_name(), {:pause}

    Collector.add!(["ms.com"])
    set_clock(fn -> 1001 end)
    Collector.add!(["ya.com"])
    set_clock(fn -> 1002 end)

    mset = Collector.get(1000, 1000)
    assert assert ["ms.com"] = MapSet.to_list(mset)

    mset = Collector.get(1000, 1001)
    assert assert ["ms.com", "ya.com"] = Enum.sort(MapSet.to_list(mset))

    send Writer.process_name(), {:resume}
    Writer.sync()

    # clean cache after save
    mset = Collector.get(1000, 1001)
    assert assert [] = MapSet.to_list(mset)

    # restore clock
    set_clock_and_clean(nil)
  end

  defp set_clock(clock) do
    send Collector.process_name(), {:setclock, clock}
    Collector.sync()
  end

  defp set_clock_and_clean(clock) do
    send Collector.process_name(), {:reset, clock}
    Collector.clean!()
    clean_db()
  end
end
