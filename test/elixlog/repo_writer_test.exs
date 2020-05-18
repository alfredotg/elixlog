defmodule Elixlog.RepoWriterTest do
  use ElixlogWeb.ConnCase
  alias Elixlog.Repo.Writer
  alias Elixlog.Repo.Storage

  test "Writer.xadd", %{conn: _} do
    clean_db()

    send Writer.process_name(), {:xadd, 10, ["ya.ru", 1], nil}
    send Writer.process_name(), {:xadd, 10, ["ya.ru", 1], self()}

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
