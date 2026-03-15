#!/bin/bash

# Navigate to the project directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
cd "$SCRIPT_DIR/.." || exit

# Create backups directory if it doesn't exist
BACKUP_DIR="backups"
mkdir -p "$BACKUP_DIR"

# Generate timestamp
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
BACKUP_FILE="$BACKUP_DIR/climbing_app_backup_$TIMESTAMP.tar.gz"

# Create a temporary staging area for the backup
TEMP_DIR="$BACKUP_DIR/temp_$TIMESTAMP"
mkdir -p "$TEMP_DIR"

echo "Extracting database from container securely..."
docker cp climbing-wall-backend:/app/data/climbing_wall.db "$TEMP_DIR/climbing_wall.db"

echo "Backing up uploaded photos..."
cp -r photos "$TEMP_DIR/"

echo "Zipping backup archive..."
# Tar and zip the staging folder
tar -czf "$BACKUP_FILE" -C "$TEMP_DIR" .

# Cleanup staging area
rm -rf "$TEMP_DIR"

echo "Backup saved to $BACKUP_FILE"

# Optional: Keep only the last 4 backups (approx 1 month if run weekly) to save disk space
ls -1tr "$BACKUP_DIR"/climbing_app_backup_*.tar.gz 2>/dev/null | head -n -4 | xargs -r rm -f --

echo "Backup process complete."
