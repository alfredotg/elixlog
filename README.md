# Elixlog

Сервер сохраняет уникальные домены из запроса в Redis-stream.

Точка входа - lib/elixlog_web/controllers/visited_controller.ex

Затем домены передаются в lib/elixlog/repo.ex.

Который, в свою очередь, использует коллектор lib/elixlog/repo/collector.ex.

Коллектор собирает уникальные доммены и сохраняет их раз в секунду в Redis. Не важно сколько было запросов за эту секунду, будет создана только одна запись в Redis.

Чтобы задержки записи или сети не влияли на время записываемых данных, коллектор не пишет самостоятельно в Redis, а посылает сообщения в lib/elixlog/repo/writer.ex.

Из-за ограничения хранилища stream в Redis, время на сервере должно идти строго монотонно, иначе будут теряться данные.


## Запуск Docker контейнера сервера 
```
docker-compose up
```
Сервер запуститься на адресе http://localhost:4005.
После этого можно запустить пример клиента на php - 
```
php examples/api-usage-example.php
```                               

## Локальный запуск сервера
```
mix deps.get 
mix phx.server
```
Cоединение с Redis можно настроить в файле - config/dev.exs

## Запуск тестов
```
mix test
```
Для запуска тестов нужно настроить соединение с Redis в файле - config/test.exs


### Зборка docker
docker build -t alfredotg/elixlog ./


