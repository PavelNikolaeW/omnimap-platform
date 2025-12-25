# OmniMap Platform

## Обзор

Монорепозиторий для оркестрации микросервисов OmniMap через git submodules.

## Структура

```
omnimap-platform/
├── services/                    # Git submodules с микросервисами
│   ├── omnimap-back/           # Django REST API + Celery
│   ├── omnimap-front/          # React фронтенд
│   ├── omnimap-sync/           # WebSocket синхронизация
│   └── llm-gateway/            # FastAPI для LLM
├── infrastructure/             # Docker Compose для локальной разработки
│   ├── docker-compose.yml
│   ├── .env.example
│   └── init-db/
├── deploy/                     # Kubernetes манифесты
│   └── kubernetes/
│       ├── base/              # Базовые ресурсы
│       └── overlays/          # Dev/Prod конфигурации
├── scripts/                   # Утилиты
├── Makefile                   # Команды управления
└── CLAUDE.md
```

## Сервисы

| Сервис | Порт | Технология | Описание |
|--------|------|------------|----------|
| omnimap-back | 8000 | Django + Celery | REST API для фронтенда, аутентификация |
| omnimap-front | 3000 | React | Пользовательский интерфейс |
| omnimap-sync | 7999 | Python/WebSocket | Синхронизация данных между пользователями |
| llm-gateway | 8001 | FastAPI | API Gateway для LLM провайдеров |

## Репозитории

- `services/omnimap-back` → `git@github.com:PavelNikolaeW/omnimap-back.git`
- `services/omnimap-front` → `git@github.com:PavelNikolaeW/omnimap-front.git`
- `services/omnimap-sync` → `git@github.com:PavelNikolaeW/omnimap-sync.git`
- `services/llm-gateway` → `git@github.com:PavelNikolaeW/llm_gateway.git`

## Технологии

- **Backend**: Python 3.11+, Django, FastAPI, Celery
- **Frontend**: React, TypeScript
- **Database**: PostgreSQL 15
- **Cache/Queue**: Redis 7, RabbitMQ 3.12
- **Containers**: Docker Compose (local), Kubernetes (prod)
- **Cloud**: cloud.ru

## Быстрый старт

```bash
# Инициализация проекта
make init

# Отредактировать конфигурацию
vim infrastructure/.env

# Запустить все сервисы
make up

# Просмотр логов
make logs
```

## Основные команды

| Команда | Описание |
|---------|----------|
| `make init` | Инициализация проекта |
| `make up` | Запустить все сервисы |
| `make down` | Остановить сервисы |
| `make build` | Собрать образы |
| `make logs` | Логи всех сервисов |
| `make ps` | Статус контейнеров |
| `make deploy-dev` | Деплой в dev (K8s) |
| `make deploy-prod` | Деплой в prod (K8s) |

## Порты

| Сервис | Порт | URL |
|--------|------|-----|
| Frontend | 3000 | http://localhost:3000 |
| Backend API | 8000 | http://localhost:8000 |
| Sync WebSocket | 7999 | ws://localhost:7999 |
| LLM Gateway | 8001 | http://localhost:8001 |
| PostgreSQL | 5432 | - |
| Redis | 6379 | - |
| RabbitMQ | 5672 | - |
| RabbitMQ UI | 15672 | http://localhost:15672 |

## Kubernetes (cloud.ru)

Домены:
- `omnimap.cloud.ru` — Frontend
- `api.omnimap.cloud.ru` — Backend API
- `sync.omnimap.cloud.ru` — WebSocket
- `llm.omnimap.cloud.ru` — LLM Gateway

## TODO

- [x] Настроить infrastructure/docker-compose.yml
- [x] Настроить deploy/kubernetes
- [ ] CI/CD pipeline (GitHub Actions)
- [ ] Настроить TLS сертификаты для K8s
- [ ] Мониторинг (Prometheus + Grafana)
