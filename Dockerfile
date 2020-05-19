FROM elixir
EXPOSE 4000
WORKDIR /app
RUN mix local.hex --force && \
  mix local.rebar --force
COPY ./mix.exs ./mix.exs 
RUN mix deps.get 
RUN mix deps.compile
COPY ./config ./config
COPY ./lib ./lib 
COPY ./priv ./priv 
COPY ./test ./test
RUN mix compile 
CMD ["mix", "phx.server"]
