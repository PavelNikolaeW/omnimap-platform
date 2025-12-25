#!/bin/bash
# OmniMap Platform - Restore Script
# Восстанавливает данные из резервной копии

set -e

BACKUP_DIR="${BACKUP_DIR:-./backups}"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Проверяем аргумент
if [ -z "$1" ]; then
    echo -e "${YELLOW}Usage: $0 <backup_file.tar.gz>${NC}"
    echo ""
    echo "Available backups:"
    ls -lh "$BACKUP_DIR"/backup_*.tar.gz 2>/dev/null || echo "No backups found in $BACKUP_DIR"
    exit 1
fi

BACKUP_FILE="$1"

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
read -p "Are you sure? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Restore cancelled."
    exit 0
fi

echo ""
echo -e "${GREEN}=== OmniMap Restore ===${NC}"

# Создаем временную директорию
TEMP_DIR=$(mktemp -d)
echo "Extracting backup to $TEMP_DIR..."
tar -xzf "$BACKUP_FILE" -C "$TEMP_DIR"
BACKUP_DATA=$(ls "$TEMP_DIR")

# PostgreSQL restore
if [ -f "$TEMP_DIR/$BACKUP_DATA/postgres_all.sql" ]; then
    echo -e "${YELLOW}Restoring PostgreSQL...${NC}"
    docker exec -i omnimap-postgres psql -U omnimap -d postgres < "$TEMP_DIR/$BACKUP_DATA/postgres_all.sql"
    echo -e "${GREEN}✓ PostgreSQL restored${NC}"
else
    echo -e "${YELLOW}No PostgreSQL backup found, skipping...${NC}"
fi

# Redis restore
if [ -f "$TEMP_DIR/$BACKUP_DATA/redis_dump.rdb" ]; then
    echo -e "${YELLOW}Restoring Redis...${NC}"
    docker cp "$TEMP_DIR/$BACKUP_DATA/redis_dump.rdb" omnimap-redis:/data/dump.rdb
    docker exec omnimap-redis redis-cli DEBUG RELOAD
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
echo "You may need to restart services: make down && make up"
