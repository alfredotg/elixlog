defmodule Elixlog.RepoWriterTest do
  use ElixlogWeb.ConnCase
  alias Elixlog.Repo.Writer
  alias Elixlog.Repo

  test "Writer.xadd", %{conn: _} do
    clean_db()

    send Writer.process_name(), {:xadd, Repo.redis_key, 10, ["ya.ru", 1], nil}
    send Writer.process_name(), {:xadd, Repo.redis_key, 10, ["ya.ru", 1], self()}

    receive do
      {:ok} ->
        {:ok}
    after
      1000 ->
        raise "Timeout"
    end

    {:ok, list} = Redix.command(:redix, ["XRANGE", Repo.redis_key, "-", "+"])
    assert assert [["10-1", ["ya.ru", "1"]], ["10-2", ["ya.ru", "1"]]] = list
  end
end
