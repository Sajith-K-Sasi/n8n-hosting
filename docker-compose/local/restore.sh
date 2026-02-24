#!/bin/bash

# n8n Restore Script
# Restores workflows and credentials from backup files

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="${SCRIPT_DIR}/backups"

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -b, --backup TIMESTAMP    Restore from specific backup timestamp (YYYYMMDD_HHMMSS)"
    echo "  -l, --latest              Restore from latest backup"
    echo "  -w, --workflows FILE      Restore workflows only from specified file"
    echo "  -c, --credentials FILE    Restore credentials only from specified file"
    echo "  -h, --help                Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --latest                              # Restore everything from latest backup"
    echo "  $0 --backup 20250224_120000              # Restore from specific backup"
    echo "  $0 --workflows ./backups/latest/workflows.json     # Restore workflows only"
    echo "  $0 --credentials ./my-credentials.json   # Restore credentials only"
    exit 1
}

# Parse arguments
RESTORE_TYPE=""
BACKUP_TIMESTAMP=""
WORKFLOWS_FILE=""
CREDENTIALS_FILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -b|--backup)
            BACKUP_TIMESTAMP="$2"
            RESTORE_TYPE="full"
            shift 2
            ;;
        -l|--latest)
            RESTORE_TYPE="full"
            shift
            ;;
        -w|--workflows)
            WORKFLOWS_FILE="$2"
            RESTORE_TYPE="workflows"
            shift 2
            ;;
        -c|--credentials)
            CREDENTIALS_FILE="$2"
            RESTORE_TYPE="credentials"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

if [ -z "$RESTORE_TYPE" ]; then
    echo "Error: No restore option specified"
    usage
fi

# Get running n8n container name
CONTAINER_NAME=$(docker compose ps -q n8n 2>/dev/null || true)

if [ -z "$CONTAINER_NAME" ]; then
    echo "Error: n8n container is not running"
    echo "Please start n8n first with: docker compose up -d"
    exit 1
fi

echo "Found n8n container: $CONTAINER_NAME"

# Resolve backup paths
if [ "$RESTORE_TYPE" = "full" ]; then
    if [ -z "$BACKUP_TIMESTAMP" ]; then
        # Use latest symlink
        if [ -L "${BACKUP_DIR}/latest" ]; then
            BACKUP_PATH=$(readlink -f "${BACKUP_DIR}/latest")
            echo "Using latest backup: $BACKUP_PATH"
        else
            echo "Error: No latest backup found"
            exit 1
        fi
    else
        BACKUP_PATH="${BACKUP_DIR}/${BACKUP_TIMESTAMP}"
        if [ ! -d "$BACKUP_PATH" ]; then
            echo "Error: Backup not found: $BACKUP_PATH"
            exit 1
        fi
    fi
    
    WORKFLOWS_FILE="${BACKUP_PATH}/workflows.json"
    CREDENTIALS_FILE="${BACKUP_PATH}/credentials.json"
fi

# Restore credentials first (workflows may depend on them)
if [ -n "$CREDENTIALS_FILE" ] && [ -f "$CREDENTIALS_FILE" ]; then
    echo "Restoring credentials from: $CREDENTIALS_FILE"
    
    # Copy file to container
    FILENAME=$(basename "$CREDENTIALS_FILE")
    docker cp "$CREDENTIALS_FILE" "$CONTAINER_NAME":/tmp/"$FILENAME"
    
    # Import credentials
    docker exec "$CONTAINER_NAME" n8n import:credentials --input=/tmp/"$FILENAME" || {
        echo "Error: Failed to import credentials"
        exit 1
    }
    
    echo "Credentials restored successfully"
else
    if [ "$RESTORE_TYPE" = "full" ] || [ "$RESTORE_TYPE" = "credentials" ]; then
        echo "Warning: Credentials file not found: $CREDENTIALS_FILE"
    fi
fi

# Restore workflows
if [ -n "$WORKFLOWS_FILE" ] && [ -f "$WORKFLOWS_FILE" ]; then
    echo "Restoring workflows from: $WORKFLOWS_FILE"
    
    # Copy file to container
    FILENAME=$(basename "$WORKFLOWS_FILE")
    docker cp "$WORKFLOWS_FILE" "$CONTAINER_NAME":/tmp/"$FILENAME"
    
    # Import workflows
    docker exec "$CONTAINER_NAME" n8n import:workflow --input=/tmp/"$FILENAME" || {
        echo "Error: Failed to import workflows"
        exit 1
    }
    
    echo "Workflows restored successfully"
else
    if [ "$RESTORE_TYPE" = "full" ] || [ "$RESTORE_TYPE" = "workflows" ]; then
        echo "Warning: Workflows file not found: $WORKFLOWS_FILE"
    fi
fi

echo ""
echo "Restore completed!"
echo "You may need to refresh your n8n web interface to see the restored data."
