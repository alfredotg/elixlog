use Mix.Config

# Configure your database
config :elixlog, Elixlog.Repo,
  hostname: "localhost",
  port: 6379,
  database: 3

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :elixlog, ElixlogWeb.Endpoint,
  http: [port: 4002],
  server: false

# Print only warnings and errors during test
config :logger, level: :warn
