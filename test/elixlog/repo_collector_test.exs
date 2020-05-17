defmodule Elixlog.RepoTest do
  use ElixlogWeb.ConnCase
  alias Elixlog.Repo.Collector
  alias Elixlog.Repo.Writer
  alias Elixlog.Repo

  defp clean_db do
    {:ok, _} = Redix.command(:redix, ["DEL", Repo.redis_key])
  end

  test "Collector.get", %{conn: _} do
    clean_db()

    Collector.clean!()
    now = DateTime.utc_now() |> DateTime.to_unix()
    {list, time} = Collector.get()
    assert assert [] = list
    assert now - time <= 1
  end

  test "Collector.add", %{conn: _} do
    clean_db()
    Collector.clean!()

    set_clock_and_clean(fn -> 1000 end)

    Collector.add!(["ya.ru", "google.com"])
    Collector.add!(["ms.com"])
    # collector collects domains
    {list, time} = Collector.get()
    list = Enum.sort(list)
    assert assert 1000 = time
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
    {list, time} = Collector.get()
    list = Enum.sort(list)
    assert assert 1001 = time
    assert assert [] = list

    {:ok, list} = Repo.get_domains(1000, 1000)
    list = Enum.sort(list)
    assert assert ["google.com", "ms.com", "ya.ru"] = list

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
