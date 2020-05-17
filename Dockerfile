FROM elixir
EXPOSE 4000
WORKDIR /app
RUN mix local.hex --force
COPY ./ ./
CMD ["mix", "phx.server"]

