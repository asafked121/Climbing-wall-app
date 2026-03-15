#!/bin/bash

# Navigate to the project directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
cd "$SCRIPT_DIR/.." || exit

echo "Restarting containers to flush memory..."
docker compose restart

echo "Restart complete at $(date)"
