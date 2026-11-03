# Infra Monitoring Project

Учебный проект по мониторингу инфраструктуры, анализу логов, контейнеризации сервисов и автоматизации проверок в CI/CD.

## Структура проекта

```text
infra-monitoring-project/
├── .github/
│   └── workflows/
│       └── ci.yml          # Пайплайн GitHub Actions для проверки и тестирования скриптов
├── .gitattributes          # Принудительные окончания строк LF для *.sh
├── .gitignore              # Исключение логов, временных файлов и дампов трафика
├── analyze_logs.sh         # Генерация access.log (350 записей) и подсчёт статистики (grep/awk)
├── check_api.sh            # Проверка доступности HTTP API по URL
├── docker-compose.yml      # Описание сервисов api (http-echo) и proxy (nginx) в общей сети
├── nginx.conf              # Конфигурация reverse proxy Nginx для проксирования на api:8080
└── README.md               # Документация проекта
```

---

## Запуск и использование

> Рекомендуется выполнять команды в **Git Bash** (на Windows) или любом стандартном bash-терминале в Linux/macOS.

### 1. Проверка доступности API (`check_api.sh`)

Скрипт принимает URL в качестве аргумента, отправляет HTTP-запрос через `curl` (с таймаутом 10 секунд и до 3 повторов) и проверяет, равен ли HTTP-код ответа `200`.

**Команды запуска:**

```bash
chmod +x check_api.sh

# Успешная проверка (код возврата 0)
./check_api.sh https://httpbin.org/status/200

# Неуспешная проверка — ошибка 404 (код возврата 1)
./check_api.sh https://httpbin.org/status/404

# Несуществующий хост (код возврата 1)
./check_api.sh http://nonexistent.invalid
```

**Пример вывода:**

```text
$ ./check_api.sh https://httpbin.org/status/200
API доступен, код ответа: 200

$ ./check_api.sh https://httpbin.org/status/404
API недоступен, код ответа: 404

$ ./check_api.sh http://nonexistent.invalid
API недоступен, код ответа: 000
```

---

### 2. Генерация и анализ логов (`analyze_logs.sh`)

Скрипт генерирует файл `access.log` из 350 строк в формате логов веб-сервера и выводит сводную статистику:
- общее число запросов (`wc -l`);
- топ-3 IP-адреса по количеству обращений (регулярное выражение `grep -oE`, сортировка и подсчёт `uniq -c`);
- количество клиентских (`4xx`) и серверных (`5xx`) ошибок с помощью `awk`.

**Команда запуска:**

```bash
chmod +x analyze_logs.sh
./analyze_logs.sh
```

**Пример вывода:**

```text
Общее число запросов: 350

Топ-3 IP:
    150 192.168.1.10
    109 192.168.1.20
     55 172.16.0.1

Количество 4xx: 143
Количество 5xx: 100
```

---

### 3. Запуск сервисов в Docker Compose

В проекте настроены два контейнера в изолированной bridge-сети `monitoring`:
- **`api`** (`hashicorp/http-echo`) — слушает внутренний порт `8080` и возвращает текст `Monitoring Service Active`. Внешний порт не публикуется.
- **`proxy`** (`nginx:alpine`) — принимает запросы на внешнем порту `80` и проксирует их на `http://api:8080`.

**Команды запуска и проверки:**

```bash
# Запуск контейнеров в фоновом режиме
docker compose up -d

# Проверка статуса контейнеров
docker compose ps

# Проверка ответа через reverse proxy
curl http://localhost:80
```

**Пример вывода:**

```text
$ docker compose ps
NAME                               IMAGE                 COMMAND                  SERVICE   CREATED          STATUS          PORTS
infra-monitoring-project-api-1     hashicorp/http-echo   "/http-echo -listen=…"   api       10 seconds ago   Up 9 seconds    5678/tcp
infra-monitoring-project-proxy-1   nginx:alpine          "/docker-entrypoint.…"   proxy     10 seconds ago   Up 8 seconds    0.0.0.0:80->80/tcp, [::]:80->80/tcp

$ curl http://localhost:80
Monitoring Service Active
```

Для остановки контейнеров:

```bash
docker compose down
```

---

## CI/CD (GitHub Actions)

Пайплайн `.github/workflows/ci.yml` автоматически запускается при создании и обновлении Pull Request в ветку `main` и выполняет:
1. Проверку синтаксиса `bash -n check_api.sh` и `bash -n analyze_logs.sh`.
2. Функциональный тест `./check_api.sh https://httpbin.org/status/200`.
3. Запуск `./analyze_logs.sh` с проверкой корректного расчёта статистики (`Общее число запросов: 350`).

---

## Инструкция по деплою на удалённый сервер

Ниже приведён порядок развёртывания проекта на удалённом Linux-сервере (`user@your-server`) по SSH.

### 1. Настройка SSH-доступа по ключу

Сгенерируйте SSH-ключ (если его ещё нет) и скопируйте публичный ключ на сервер:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_deploy -C "deploy@infra-monitoring"
ssh-copy-id -i ~/.ssh/id_ed25519_deploy.pub user@your-server
```

### 2. Архивация и передача файлов на сервер

Упакуйте файлы проекта в архив, исключив каталог `.git`, логи и дампы трафика, и отправьте архив на сервер:

**Вариант А — через `tar` и `scp`:**

```bash
tar --exclude='.git' --exclude='*.log' --exclude='*.tmp' --exclude='*.pcapng' -czf project.tar.gz .
scp -i ~/.ssh/id_ed25519_deploy project.tar.gz user@your-server:~/project.tar.gz
ssh -i ~/.ssh/id_ed25519_deploy user@your-server "mkdir -p ~/infra-monitoring-project && tar -xzf ~/project.tar.gz -C ~/infra-monitoring-project && rm ~/project.tar.gz"
rm project.tar.gz
```

**Вариант Б — потоковая передача `tar + ssh` без промежуточного файла:**

```bash
tar --exclude='.git' --exclude='*.log' --exclude='*.tmp' --exclude='*.pcapng' -czf - . \
  | ssh -i ~/.ssh/id_ed25519_deploy user@your-server "mkdir -p ~/infra-monitoring-project && tar -xzf - -C ~/infra-monitoring-project"
```

### 3. Запуск сервисов на сервере

Подключитесь к серверу и запустите Docker Compose:

```bash
ssh -i ~/.ssh/id_ed25519_deploy user@your-server
cd ~/infra-monitoring-project
chmod +x check_api.sh analyze_logs.sh
docker compose up -d
docker compose ps
curl http://localhost:80
```
