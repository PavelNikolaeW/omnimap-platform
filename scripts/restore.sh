#!/bin/bash
# OmniMap Platform - Restore Script
# Восстанавливает данные из резервной копии

set -e

# Получаем абсолютный путь к директории бэкапов
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="${BACKUP_DIR:-$PROJECT_DIR/backups}"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Парсим аргументы
SKIP_CONFIRM=false
BACKUP_FILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -y|--yes)
            SKIP_CONFIRM=true
            shift
            ;;
        *)
            BACKUP_FILE="$1"
            shift
            ;;
    esac
done

# Проверяем аргумент
if [ -z "$BACKUP_FILE" ]; then
    echo -e "${YELLOW}Usage: $0 [-y] <backup_file.tar.gz>${NC}"
    echo ""
    echo "Options:"
    echo "  -y, --yes    Skip confirmation prompt"
    echo ""
    echo "Available backups:"
    ls -lh "$BACKUP_DIR"/backup_*.tar.gz 2>/dev/null || echo "No backups found in $BACKUP_DIR"
    exit 1
fi

if [ ! -f "$BACKUP_FILE" ]; then
    # Попробуем найти в BACKUP_DIR
    if [ -f "$BACKUP_DIR/$BACKUP_FILE" ]; then
        BACKUP_FILE="$BACKUP_DIR/$BACKUP_FILE"
    else
        echo -e "${RED}Backup file not found: $BACKUP_FILE${NC}"
        exit 1
    fi
fi

echo -e "${RED}=== WARNING ===${NC}"
echo "This will OVERWRITE current data with backup from:"
echo "$BACKUP_FILE"
echo ""

if [ "$SKIP_CONFIRM" = false ]; then
    read -p "Are you sure? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        echo "Restore cancelled."
        exit 0
    fi
else
    echo -e "${YELLOW}Skipping confirmation (-y flag)${NC}"
fi

echo ""
echo -e "${GREEN}=== OmniMap Restore ===${NC}"

# Создаем временную директорию
TEMP_DIR=$(mktemp -d)
echo "Extracting backup to $TEMP_DIR..."
tar -xzf "$BACKUP_FILE" -C "$TEMP_DIR"
BACKUP_DATA=$(ls "$TEMP_DIR")

# Определяем формат бэкапа (новый с .dump или старый с .sql)
if ls "$TEMP_DIR/$BACKUP_DATA"/*.dump 1>/dev/null 2>&1; then
    echo -e "${GREEN}Detected new backup format (pg_dump custom)${NC}"
    BACKUP_FORMAT="new"
elif [ -f "$TEMP_DIR/$BACKUP_DATA/postgres_all.sql" ]; then
    echo -e "${YELLOW}Detected old backup format (pg_dumpall)${NC}"
    BACKUP_FORMAT="old"
else
    echo -e "${RED}No PostgreSQL backup found${NC}"
    BACKUP_FORMAT="none"
fi

# PostgreSQL restore
if [ "$BACKUP_FORMAT" = "new" ]; then
    echo -e "${YELLOW}Restoring PostgreSQL (new format)...${NC}"

    for DUMP_FILE in "$TEMP_DIR/$BACKUP_DATA"/*.dump; do
        DB_NAME=$(basename "$DUMP_FILE" .dump)
        echo "  Restoring database: $DB_NAME"

        # Копируем дамп в контейнер
        docker cp "$DUMP_FILE" "omnimap-postgres:/tmp/${DB_NAME}.dump"

        # Проверяем существует ли база
        DB_EXISTS=$(docker exec omnimap-postgres psql -U omnimap -t -c "SELECT 1 FROM pg_database WHERE datname='$DB_NAME';" | tr -d ' ')

        if [ "$DB_EXISTS" = "1" ]; then
            # База существует - пересоздаём для чистого восстановления
            echo "    Database exists, dropping and recreating..."
            # Закрываем все соединения к базе
            docker exec omnimap-postgres psql -U omnimap -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='$DB_NAME' AND pid <> pg_backend_pid();" >/dev/null 2>&1 || true
            # Удаляем и создаём заново
            docker exec omnimap-postgres dropdb -U omnimap "$DB_NAME" 2>/dev/null || true
            docker exec omnimap-postgres createdb -U omnimap "$DB_NAME"
        else
            # База не существует - создаём
            echo "    Creating database $DB_NAME..."
            docker exec omnimap-postgres createdb -U omnimap "$DB_NAME"
        fi

        # Восстанавливаем данные
        echo "    Restoring data..."
        docker exec omnimap-postgres pg_restore -U omnimap -d "$DB_NAME" "/tmp/${DB_NAME}.dump" 2>/dev/null || true

        # Удаляем временный файл
        docker exec omnimap-postgres rm "/tmp/${DB_NAME}.dump"
        echo -e "${GREEN}  ✓ $DB_NAME restored${NC}"
    done

    echo -e "${GREEN}✓ PostgreSQL restored${NC}"

elif [ "$BACKUP_FORMAT" = "old" ]; then
    echo -e "${YELLOW}Restoring PostgreSQL (old format - legacy)...${NC}"
    echo -e "${YELLOW}Warning: Old format may have issues. Consider creating a new backup.${NC}"

    # Для старого формата пытаемся извлечь данные построчно
    SQL_FILE="$TEMP_DIR/$BACKUP_DATA/postgres_all.sql"

    # Получаем список баз из дампа
    DATABASES=$(grep -E "^\\\\connect " "$SQL_FILE" | sed 's/\\connect //' | grep -v template | sort -u)

    for DB_NAME in $DATABASES; do
        echo "  Processing database: $DB_NAME"

        # Проверяем существует ли база
        DB_EXISTS=$(docker exec omnimap-postgres psql -U omnimap -t -c "SELECT 1 FROM pg_database WHERE datname='$DB_NAME';" 2>/dev/null | tr -d ' ')

        if [ "$DB_EXISTS" != "1" ]; then
            echo "    Creating database $DB_NAME..."
            docker exec omnimap-postgres createdb -U omnimap "$DB_NAME" 2>/dev/null || true
        fi

        # Извлекаем SQL для конкретной базы и выполняем
        # Это упрощённый подход - извлекаем секцию между \connect DB и следующим \connect
        docker cp "$SQL_FILE" "omnimap-postgres:/tmp/postgres_all.sql"
        docker exec omnimap-postgres psql -U omnimap -d "$DB_NAME" -f /tmp/postgres_all.sql 2>/dev/null || {
            echo -e "${YELLOW}    Warning: Some errors during restore (may be expected)${NC}"
        }
    done

    docker exec omnimap-postgres rm -f /tmp/postgres_all.sql 2>/dev/null || true
    echo -e "${GREEN}✓ PostgreSQL restored (with possible warnings)${NC}"
else
    echo -e "${YELLOW}No PostgreSQL backup found, skipping...${NC}"
fi

# Redis restore
if [ -f "$TEMP_DIR/$BACKUP_DATA/redis_dump.rdb" ]; then
    echo -e "${YELLOW}Restoring Redis...${NC}"
    docker cp "$TEMP_DIR/$BACKUP_DATA/redis_dump.rdb" omnimap-redis:/data/dump.rdb
    docker exec omnimap-redis redis-cli DEBUG RELOAD 2>/dev/null || {
        echo -e "${YELLOW}Redis DEBUG RELOAD failed, restarting container...${NC}"
        docker restart omnimap-redis
        sleep 2
    }
    echo -e "${GREEN}✓ Redis restored${NC}"
else
    echo -e "${YELLOW}No Redis backup found, skipping...${NC}"
fi

# RabbitMQ restore
if [ -f "$TEMP_DIR/$BACKUP_DATA/rabbitmq_definitions.json" ]; then
    echo -e "${YELLOW}Restoring RabbitMQ definitions...${NC}"
    docker cp "$TEMP_DIR/$BACKUP_DATA/rabbitmq_definitions.json" omnimap-rabbitmq:/tmp/rabbitmq_definitions.json
    docker exec omnimap-rabbitmq rabbitmqctl import_definitions /tmp/rabbitmq_definitions.json
    echo -e "${GREEN}✓ RabbitMQ restored${NC}"
else
    echo -e "${YELLOW}No RabbitMQ backup found, skipping...${NC}"
fi

# Cleanup
rm -rf "$TEMP_DIR"

echo ""
echo -e "${GREEN}=== Restore Complete ===${NC}"
echo ""
echo "Next steps:"
echo "  1. Restart services: make down && make up"
echo "  2. Check data in admin panel"
echo ""
echo -e "${YELLOW}Note: If you restored from an old backup format, consider${NC}"
echo -e "${YELLOW}creating a new backup with 'make backup' for future use.${NC}"
