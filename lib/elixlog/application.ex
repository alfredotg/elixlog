defmodule Elixlog.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      ElixlogWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Elixlog.PubSub},
      # Start redis client
      {Elixlog.Repo.Storage, [name: Elixlog.Repo.storage_process()] ++ Application.get_env(:elixlog, Elixlog.Repo)},
      {Elixlog.Repo.Writer, [name: Elixlog.Repo.Writer, storage: Elixlog.Repo.storage_process()]},
      {Elixlog.Repo.Collector, [name: Elixlog.Repo.collector_process(), writer: ElixlogWeb.Repo.Writer]},
      # Start the Endpoint (http/https)
      ElixlogWeb.Endpoint
      # Start a worker by calling: Elixlog.Worker.start_link(arg)
      # {Elixlog.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Elixlog.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    ElixlogWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
