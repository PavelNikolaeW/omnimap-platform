#!/bin/bash
# OmniMap Platform - Backup Script
# Создает резервные копии PostgreSQL, Redis и RabbitMQ

set -e

# Получаем абсолютный путь к директории бэкапов
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="${BACKUP_DIR:-$PROJECT_DIR/backups}"
# Преобразуем в абсолютный путь
BACKUP_DIR="$(cd "$(dirname "$BACKUP_DIR")" 2>/dev/null && pwd)/$(basename "$BACKUP_DIR")" || BACKUP_DIR="$PROJECT_DIR/backups"
mkdir -p "$BACKUP_DIR"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="$BACKUP_DIR/$TIMESTAMP"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Базы данных для бэкапа
DATABASES=("omnimap" "llm_gateway")

echo -e "${GREEN}=== OmniMap Backup ===${NC}"
echo "Timestamp: $TIMESTAMP"
echo "Backup path: $BACKUP_PATH"
echo ""

# Создаем директорию для бэкапа
mkdir -p "$BACKUP_PATH"

# Сохраняем текущую директорию
ORIGINAL_DIR="$(pwd)"

# PostgreSQL backup - каждая база отдельно в custom format
echo -e "${YELLOW}Backing up PostgreSQL...${NC}"

for DB in "${DATABASES[@]}"; do
    echo "  Dumping database: $DB"
    docker exec omnimap-postgres pg_dump -U omnimap -Fc -f "/tmp/${DB}.dump" "$DB" 2>/dev/null || {
        echo -e "${YELLOW}  Warning: Database $DB not found, skipping${NC}"
        continue
    }
    docker cp "omnimap-postgres:/tmp/${DB}.dump" "$BACKUP_PATH/${DB}.dump"
    docker exec omnimap-postgres rm "/tmp/${DB}.dump"
    echo -e "${GREEN}  ✓ $DB dumped${NC}"
done

# Также сохраняем список баз для восстановления
docker exec omnimap-postgres psql -U omnimap -t -c "SELECT datname FROM pg_database WHERE datistemplate = false AND datname NOT IN ('postgres');" | tr -d ' ' | grep -v '^$' > "$BACKUP_PATH/databases.txt"

echo -e "${GREEN}✓ PostgreSQL backup complete${NC}"

# Redis backup (RDB snapshot)
echo -e "${YELLOW}Backing up Redis...${NC}"
docker exec omnimap-redis redis-cli BGSAVE
sleep 2
docker cp omnimap-redis:/data/dump.rdb "$BACKUP_PATH/redis_dump.rdb" 2>/dev/null || echo "No Redis dump found (empty DB)"
echo -e "${GREEN}✓ Redis backup complete${NC}"

# RabbitMQ definitions export
echo -e "${YELLOW}Backing up RabbitMQ definitions...${NC}"
docker exec omnimap-rabbitmq rabbitmqctl export_definitions /tmp/rabbitmq_definitions.json
docker cp omnimap-rabbitmq:/tmp/rabbitmq_definitions.json "$BACKUP_PATH/rabbitmq_definitions.json"
echo -e "${GREEN}✓ RabbitMQ backup complete${NC}"

# Создаем архив
echo -e "${YELLOW}Creating archive...${NC}"
cd "$BACKUP_DIR"
tar -czf "backup_$TIMESTAMP.tar.gz" "$TIMESTAMP"
rm -rf "$TIMESTAMP"
echo -e "${GREEN}✓ Archive created: $BACKUP_DIR/backup_$TIMESTAMP.tar.gz${NC}"

# Показываем размер
ARCHIVE_FILE="$BACKUP_DIR/backup_$TIMESTAMP.tar.gz"
SIZE=$(du -h "$ARCHIVE_FILE" | cut -f1)
echo ""
echo -e "${GREEN}=== Backup Complete ===${NC}"
echo "File: $ARCHIVE_FILE"
echo "Size: $SIZE"

# Удаляем старые бэкапы (оставляем последние 10)
echo ""
echo -e "${YELLOW}Cleaning old backups (keeping last 10)...${NC}"
ls -t "$BACKUP_DIR"/backup_*.tar.gz 2>/dev/null | tail -n +11 | xargs -r rm -f
echo -e "${GREEN}✓ Cleanup complete${NC}"

# Возвращаемся в исходную директорию
cd "$ORIGINAL_DIR"
