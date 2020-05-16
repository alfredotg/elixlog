defmodule Elixlog.Repo do
  use Ecto.Repo,
    otp_app: :elixlog,
    adapter: Ecto.Adapters.Postgres
end
