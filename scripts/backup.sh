#!/bin/bash
# OmniMap Platform - Backup Script
# Создает резервные копии PostgreSQL, Redis и RabbitMQ

set -e

BACKUP_DIR="${BACKUP_DIR:-./backups}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="$BACKUP_DIR/$TIMESTAMP"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== OmniMap Backup ===${NC}"
echo "Timestamp: $TIMESTAMP"
echo "Backup path: $BACKUP_PATH"
echo ""

# Создаем директорию для бэкапа
mkdir -p "$BACKUP_PATH"

# PostgreSQL backup
echo -e "${YELLOW}Backing up PostgreSQL...${NC}"
docker exec omnimap-postgres pg_dumpall -U omnimap > "$BACKUP_PATH/postgres_all.sql"
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
SIZE=$(du -h "$BACKUP_DIR/backup_$TIMESTAMP.tar.gz" | cut -f1)
echo ""
echo -e "${GREEN}=== Backup Complete ===${NC}"
echo "File: $BACKUP_DIR/backup_$TIMESTAMP.tar.gz"
echo "Size: $SIZE"

# Удаляем старые бэкапы (оставляем последние 10)
echo ""
echo -e "${YELLOW}Cleaning old backups (keeping last 10)...${NC}"
cd "$BACKUP_DIR"
ls -t backup_*.tar.gz 2>/dev/null | tail -n +11 | xargs -r rm -f
echo -e "${GREEN}✓ Cleanup complete${NC}"
