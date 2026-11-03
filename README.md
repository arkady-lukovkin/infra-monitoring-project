# Мониторинг API и анализ логов

Итоговая практическая работа по программной инженерии. Луковкин Аркадий Сергеевич, РИМ-160980к.

В проекте два Bash-скрипта и небольшой стенд: nginx принимает запрос на localhost:80 и передаёт его в http-echo на порту 8080. API доступен только внутри сети Docker.

## Запуск

Нужны Bash, curl, awk, grep, sort, uniq и Docker с Compose v2. Скрипты работают со стандартными утилитами macOS и Linux.

```bash
git clone https://github.com/arkady-lukovkin/infra-monitoring-project.git
cd infra-monitoring-project
git switch feature/monitoring
chmod +x check_api.sh analyze_logs.sh
docker compose up -d
docker compose ps
curl http://localhost:80
```

Ответ стенда: `Monitoring Service Active`. Порт 80 опубликован только на loopback-адресе. Сервисы общаются по имени `api` в сети `monitoring` с `internal: true`; у прокси есть отдельная внешняя сеть. Для остановки и удаления учебных контейнеров и сетей:

```bash
docker compose down
```

## Проверка API

```bash
./check_api.sh https://httpbin.org/status/200
echo $?
./check_api.sh https://httpbin.org/status/404
echo $?
./check_api.sh http://127.0.0.1:1/
echo $?
```

Только HTTP 200 считается успехом: сообщение `API доступен`, код возврата 0. Для остальных HTTP-кодов — `API недоступен, код ответа: XXX`, код возврата 1. При сетевой ошибке выводится код `000`. Перенаправления не скрываются: HTTP 302 тоже считается неуспешной проверкой. Время соединения ограничено 5 секундами, всего запроса — 15 секундами.

## Анализ логов

```bash
./analyze_logs.sh
./analyze_logs.sh access.log
```

Без аргументов скрипт создаёт или перезаписывает учебный `access.log` на 300 строк. С аргументом читает существующий файл, не меняя его. Формат соответствует примеру задания: IP, два дефиса, дата без часового пояса, метод и путь в кавычках, код ответа последним полем.

Ожидаемый результат генерации: 300 запросов; топ адресов — 192.168.1.10 (120), 10.0.0.5 (90), 192.168.1.20 (60); ответов 4xx — 90, 5xx — 30. Это синтетические данные. IPv4 извлекается регулярным выражением с проверкой диапазона каждого октета 0–255. `awk` считает запросы и ошибки, связка `sort | uniq -c | sort` строит рейтинг адресов. В исходном логе может быть больше трёх адресов; в рейтинг выводятся только первые три.

## Git и CI

Разработка ведётся в `feature/monitoring`; изменения передаются в `main` через Pull Request. Workflow `.github/workflows/ci.yml` запускается при открытии и обновлении PR в `main`. Он выполняет `bash -n` для обоих скриптов, вызывает `check_api.sh https://httpbin.org/status/200` и проверяет запуск анализа логов. Недоступность внешнего httpbin приводит к ошибке проверки, а не к ложному успешному результату.

## Передача на сервер по SSH

Ниже пример деплоя, а не заявление о выполненном развёртывании на удалённом сервере. `deploy@server.example` нужно заменить адресом своего сервера. На нём должны быть Docker, Compose и свободный порт 80.

```bash
ssh-keygen -t ed25519 -f ~/.ssh/infra_monitoring -C "infra-monitoring"
ssh-copy-id -i ~/.ssh/infra_monitoring.pub deploy@server.example
ssh -i ~/.ssh/infra_monitoring deploy@server.example 'mkdir -p ~/infra-monitoring-project'
git archive --format=tar.gz --output=/tmp/infra-monitoring.tar.gz HEAD
scp -i ~/.ssh/infra_monitoring /tmp/infra-monitoring.tar.gz deploy@server.example:~/infra-monitoring-project/
ssh -i ~/.ssh/infra_monitoring deploy@server.example \
  'cd ~/infra-monitoring-project && tar -xzf infra-monitoring.tar.gz && docker compose up -d && curl --fail http://localhost:80'
```

Для ключа следует задать парольную фразу. Отпечаток ключа сервера проверяется по независимому каналу при первом соединении; проверку host key отключать не нужно. На сервер передаётся только публичный ключ `.pub`; приватный ключ остаётся на клиенте. В `.gitignore` исключены ключи, `.env`, логи и временные архивы. Архив для деплоя содержит только файлы из Git.

## Документация

- [Docker Compose: сети](https://docs.docker.com/reference/compose-file/networks/)
- [Параметры http-echo](https://github.com/hashicorp/http-echo)
- [События запуска GitHub Actions](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#pull_request)
- [Wireshark](https://www.wireshark.org/)

