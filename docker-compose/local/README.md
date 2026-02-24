# n8n Local Docker Compose Setup

A simple Docker Compose configuration for running n8n locally with backup and restore scripts.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/install/)

## Quick Start

1. **Start n8n:**
   ```bash
   docker compose up -d
   ```

2. **Access n8n:**
   Open http://localhost:5678 in your browser

3. **Stop n8n:**
   ```bash
   docker compose down
   ```

## Configuration

Environment variables are defined in `.env`:

| Variable | Default | Description |
|----------|---------|-------------|
| `GENERIC_TIMEZONE` | `Asia/Kolkata` | Timezone for scheduling |
| `TZ` | `Asia/Kolkata` | System timezone |

To change timezone, edit the `.env` file.

## Backup

Backup workflows and credentials separately:

```bash
./backup.sh
```

Backups are saved to `backups/YYYYMMDD_HHMMSS/`:
- `workflows.json` - All workflows
- `credentials.json` - All credentials
- `database.sqlite` - Full database backup (fallback)

The latest backup is symlinked to `backups/latest`.

## Restore

### Restore everything from latest backup
```bash
./restore.sh --latest
```

### Restore from specific backup
```bash
./restore.sh --backup 20250224_143000
```

### Restore workflows only
```bash
./restore.sh --workflows ./backups/latest/workflows.json
```

### Restore credentials only
```bash
./restore.sh --credentials ./backups/latest/credentials.json
```

**Note:** Credentials are restored before workflows since workflows may depend on them.

## Data Persistence

All n8n data is stored in a Docker volume `n8n_data`. To completely reset:

```bash
docker compose down -v
```

**Warning:** This deletes all workflows, credentials, and settings.

## File Structure

```
.
├── docker-compose.yaml    # n8n service definition
├── .env                   # Environment variables
├── backup.sh              # Backup script
├── restore.sh             # Restore script
├── backups/               # Backup storage (created on first run)
└── README.md              # This file
```

## Troubleshooting

**Container won't start:**
- Check if port 5678 is in use: `lsof -i :5678`
- Check logs: `docker compose logs n8n`

**Backup/restore fails:**
- Ensure n8n container is running: `docker compose ps`
- Check container name matches in scripts

**Permission issues:**
- Scripts need execute permissions (already set by default)
- If needed: `chmod +x backup.sh restore.sh`
