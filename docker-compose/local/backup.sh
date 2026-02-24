#!/bin/bash

# n8n Backup Script
# Backs up workflows and credentials separately

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="${SCRIPT_DIR}/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Create backup directory
mkdir -p "${BACKUP_DIR}/${TIMESTAMP}"

echo "Starting n8n backup..."
echo "Backup location: ${BACKUP_DIR}/${TIMESTAMP}"

# Get running n8n container name
CONTAINER_NAME=$(docker compose ps -q n8n 2>/dev/null || true)

if [ -z "$CONTAINER_NAME" ]; then
    echo "Error: n8n container is not running"
    echo "Please start n8n first with: docker compose up -d"
    exit 1
fi

echo "Found n8n container: $CONTAINER_NAME"

# Export workflows
echo "Exporting workflows..."
docker exec "$CONTAINER_NAME" n8n export:workflow --all --output=/tmp/workflows.json > /dev/null 2>&1 || {
    echo "Warning: export:workflow command failed, trying alternative method..."
    # Alternative: copy from volume
    docker run --rm -v n8n_data:/data -v "${BACKUP_DIR}/${TIMESTAMP}:/backup" alpine cp /data/database.sqlite /backup/database.sqlite
}

# Export credentials
echo "Exporting credentials..."
docker exec "$CONTAINER_NAME" n8n export:credentials --all --output=/tmp/credentials.json > /dev/null 2>&1 || {
    echo "Warning: export:credentials command failed"
}

# Copy exported files from container
if docker exec "$CONTAINER_NAME" test -f /tmp/workflows.json 2>/dev/null; then
    docker cp "$CONTAINER_NAME":/tmp/workflows.json "${BACKUP_DIR}/${TIMESTAMP}/workflows.json"
    echo "Workflows backed up: ${BACKUP_DIR}/${TIMESTAMP}/workflows.json"
fi

if docker exec "$CONTAINER_NAME" test -f /tmp/credentials.json 2>/dev/null; then
    docker cp "$CONTAINER_NAME":/tmp/credentials.json "${BACKUP_DIR}/${TIMESTAMP}/credentials.json"
    echo "Credentials backed up: ${BACKUP_DIR}/${TIMESTAMP}/credentials.json"
fi

# Also backup the entire database as fallback
if docker exec "$CONTAINER_NAME" test -f /home/node/.n8n/database.sqlite 2>/dev/null; then
    docker cp "$CONTAINER_NAME":/home/node/.n8n/database.sqlite "${BACKUP_DIR}/${TIMESTAMP}/database.sqlite"
    echo "Database backed up: ${BACKUP_DIR}/${TIMESTAMP}/database.sqlite"
fi

# Create latest symlink
rm -f "${BACKUP_DIR}/latest"
ln -s "${TIMESTAMP}" "${BACKUP_DIR}/latest"

echo ""
echo "Backup completed successfully!"
echo "Location: ${BACKUP_DIR}/${TIMESTAMP}"
echo ""
echo "Files:"
ls -la "${BACKUP_DIR}/${TIMESTAMP}/"
