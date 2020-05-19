defmodule Elixlog.RepoWriterTest do
  use ElixlogWeb.ConnCase
  alias Elixlog.Repo.Writer
  alias Elixlog.Repo.Storage

  test "Writer.xadd", %{conn: _} do
    clean_db()

    set = MapSet.new()
    set = MapSet.put(set, "ya.ru")
    Writer.write(Writer, nil, set, 10)
    Writer.write(Writer, self(), set, 10)

    receive do
      {:xadd, _} ->
        {:ok}
    after
      1000 ->
        raise "Timeout"
    end

    {:ok, list} = Storage.xrange("-", "+")
    assert assert [["10-1", ["ya.ru", "1"]], ["10-2", ["ya.ru", "1"]]] = list
  end
end
