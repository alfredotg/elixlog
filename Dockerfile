FROM elixir
EXPOSE 4000
WORKDIR /app
RUN mix local.hex --force && \
  mix local.rebar --force
COPY ./mix.exs ./mix.exs 
RUN mix deps.get 
COPY ./config ./config
COPY ./lib ./lib 
COPY ./priv ./priv 
COPY ./test ./test
RUN mix 
CMD ["mix", "phx.server"]
