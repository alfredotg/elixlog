# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :elixlog,
  ecto_repos: [Elixlog.Repo]

# Configure your database
config :elixlog, Elixlog.Repo,
  hostname: "localhost",
  port: 6379,
  database: 1

# Configures the endpoint
config :elixlog, ElixlogWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "G65GZse+3HItVggpM3a4zd9F2dFXY9Bx4IE90jdEXh5BUWiC2ckjruFF9/BJnS56",
  render_errors: [view: ElixlogWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: Elixlog.PubSub,
  live_view: [signing_salt: "zS4mqiTE"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
