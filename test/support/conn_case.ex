defmodule ElixlogWeb.ConnCase do
  alias Elixlog.Repo
  alias Elixlog.Repo.Collector
  alias Elixlog.Repo.Writer

  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use ElixlogWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import ElixlogWeb.ConnCase

      alias ElixlogWeb.Router.Helpers, as: Routes

      # The default endpoint for testing
      @endpoint ElixlogWeb.Endpoint
    end
  end

  setup _ do
    #:ok = Ecto.Adapters.SQL.Sandbox.checkout(Elixlog.Repo)

    #unless tags[:async] do
    #  Ecto.Adapters.SQL.Sandbox.mode(Elixlog.Repo, {:shared, self()})
    #end

    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  def clean_db do
    Collector.clean!()
    Writer.sync()
    {:ok, _} = Redix.command(:redix, ["DEL", Repo.redis_key])
  end
end
